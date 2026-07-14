#!/usr/bin/env python
"""Offline transcription (quality/speed gate) via transformers.
Uso: python transcribe_hf.py <file.wav|mp3> [lang]   lang default auto
"""
import sys, time
import torch
from transformers import AutoModelForRNNT, AutoProcessor
from transformers.audio_utils import load_audio

wav = sys.argv[1]
lang = sys.argv[2] if len(sys.argv) > 2 else "auto"
model_id = "nvidia/nemotron-3.5-asr-streaming-0.6b"

t0 = time.time()
processor = AutoProcessor.from_pretrained(model_id)
model = AutoModelForRNNT.from_pretrained(model_id, dtype=torch.bfloat16, device_map="auto")
model.eval()
print(f"[load] {time.time()-t0:.1f}s  device={model.device} dtype={model.dtype}")

sr = processor.feature_extractor.sampling_rate
audio = load_audio(wav, sampling_rate=sr)
dur = len(audio) / sr

inputs = processor(audio, sampling_rate=sr, language=lang, return_tensors="pt")
inputs = inputs.to(model.device, dtype=model.dtype)

t1 = time.time()
with torch.no_grad():
    out = model.generate(**inputs, return_dict_in_generate=True)
infer = time.time() - t1
text = processor.decode(out.sequences, skip_special_tokens=True)
if isinstance(text, (list, tuple)):
    text = text[0] if text else ""

print("\n=== TRASCRIZIONE ===")
print(text)
print("====================")
rtf = infer / dur if dur > 0 else float("nan")
print(f"[speed] audio={dur:.1f}s infer={infer:.2f}s RTF={rtf:.3f} lang={lang}")
