#!/usr/bin/env python
"""Streaming cache-aware da microfono (o da file), via transformers.
- Sorgente mic (default): lo script avvia da solo `pw-record` DOPO il load del modello,
  così l'audio non si accumula nel buffer della pipe durante il caricamento.
- Sorgente file: --file <wav> per simulare lo streaming su un file.
Stampa le ipotesi parziali in tempo reale.

Uso mic:  python stream_hf.py [lang]
Uso file: python stream_hf.py --file audio/sample.wav [lang]
"""
import sys, time, threading
import numpy as np
import torch
from transformers import AutoModelForRNNT, AutoProcessor, TextIteratorStreamer

args = sys.argv[1:]
mode_file = None
if "--file" in args:
    i = args.index("--file"); mode_file = args[i+1]; del args[i:i+2]
lang = args[0] if args else "auto"
model_id = "nvidia/nemotron-3.5-asr-streaming-0.6b"
_mic_proc = None  # riferimento a pw-record per cleanup
LOOKAHEAD = 6  # 6 -> chunk ~560ms; abbassa per meno latenza

t0 = time.time()
processor = AutoProcessor.from_pretrained(model_id)
model = AutoModelForRNNT.from_pretrained(model_id, dtype=torch.bfloat16, device_map="auto")
model.eval()
processor.set_num_lookahead_tokens(LOOKAHEAD)
sr = processor.feature_extractor.sampling_rate
print(f"[load] {time.time()-t0:.1f}s device={model.device} lookahead={LOOKAHEAD} lang={lang}", file=sys.stderr)

n_first = processor.num_samples_first_audio_chunk
n_chunk = processor.num_samples_per_audio_chunk
hop = processor.feature_extractor.hop_length
n_fft = processor.feature_extractor.n_fft

def read_exact(stream, nbytes):
    buf = b""
    while len(buf) < nbytes:
        b = stream.read(nbytes - len(buf))
        if not b:
            break
        buf += b
    return buf

def audio_source_mic():
    """Avvia pw-record DOPO il load e legge s16le mono 16k dal suo stdout."""
    global _mic_proc
    import subprocess
    _mic_proc = subprocess.Popen(
        ["pw-record", "--rate", "16000", "--channels", "1", "--format", "s16", "-"],
        stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
    )
    stream = _mic_proc.stdout
    raw = read_exact(stream, n_first * 2)
    if not raw:
        return
    yield np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0, True
    while True:
        raw = read_exact(stream, n_chunk * 2)
        if len(raw) < n_chunk * 2:
            break
        yield np.frombuffer(raw, dtype="<i2").astype(np.float32) / 32768.0, False

def audio_source_file(path):
    from transformers.audio_utils import load_audio
    audio = load_audio(path, sampling_rate=sr)
    yield audio[:n_first], True
    idx = processor.num_mel_frames_first_audio_chunk
    start = idx * hop - n_fft // 2
    while (end := start + n_chunk) <= len(audio):
        yield audio[start:end], False
        idx += processor.num_mel_frames_per_audio_chunk
        start = idx * hop - n_fft // 2

source = audio_source_file(mode_file) if mode_file else audio_source_mic()

# Primo chunk -> prepara inputs iniziali (contengono lo stato/prompt lingua)
first_audio, _ = next(source)
first_inputs = processor(first_audio, sampling_rate=sr, is_streaming=True,
                         is_first_audio_chunk=True, language=lang, return_tensors="pt")
first_inputs = first_inputs.to(model.device, dtype=model.dtype)

def feat_gen():
    yield first_inputs.input_features[:, :processor.num_mel_frames_first_audio_chunk, :]
    for chunk, _ in source:
        inp = processor(chunk, sampling_rate=sr, is_streaming=True,
                        is_first_audio_chunk=False, language=lang, return_tensors="pt")
        inp = inp.to(model.device, dtype=model.dtype)
        yield inp.input_features

streamer = TextIteratorStreamer(processor.tokenizer, skip_special_tokens=True)
kwargs = {**first_inputs, "input_features": feat_gen(), "streamer": streamer}
th = threading.Thread(target=model.generate, kwargs=kwargs)
print(">>> in ascolto (Ctrl-C per fermare)...", file=sys.stderr)
tstart = time.time()
th.start()
full = []
try:
    for txt in streamer:
        full.append(txt)
        print(txt, end="", flush=True)
except KeyboardInterrupt:
    pass
finally:
    if _mic_proc is not None and _mic_proc.poll() is None:
        _mic_proc.terminate()
    th.join()
print(f"\n[done] {time.time()-tstart:.1f}s wall | testo: {''.join(full)!r}", file=sys.stderr)
