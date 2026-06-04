#!/usr/bin/env python3
"""
hey_nuc.py — "Hey Nuc" wake word → short local voice answer.

Pipeline:
  Yeti mic --arecord--> Vosk (always-on wake spotting "hey nuc")
    --> ack + face --> record question (RMS silence detection)
    --> local Whisper STT (:8787) --> Gemma 4 (llama.cpp) short IT answer
    --> piper TTS --> speakers, with the nuc_face octopus reacting (:3033).

Everything runs locally. No cloud, no API keys.

Modes:
  python hey_nuc.py                 # full always-on loop
  python hey_nuc.py --calibrate     # print what Vosk hears (tune the wake list)
  python hey_nuc.py --tts "ciao"    # test piper TTS
  python hey_nuc.py --gemma "..."   # test the Gemma short-answer step
  python hey_nuc.py --once          # one wake→answer cycle then exit (for testing)
"""
import argparse, json, os, re, subprocess, sys, tempfile, time, wave
import numpy as np
import requests
from vosk import Model, KaldiRecognizer, SetLogLevel

# ---- config (overridable via env) ----
IS_MAC = sys.platform == "darwin"
if IS_MAC:   # SSH/non-interactive shells miss Homebrew on PATH (sox lives there)
    os.environ["PATH"] = "/opt/homebrew/bin:/usr/bin:/bin:" + os.environ.get("PATH", "")
RATE   = 16000
if IS_MAC:   # Nuc self-contained on the Mac Mini: sox mic + whisper.cpp + say
    _MIC_D    = "default"   # follow the system Input device (Settings → Sound → Input)
    _VOSK_D   = "/Users/ivan/nuc/models/vosk-model-small-it-0.22"
    _STT_D    = "http://127.0.0.1:8089/inference"
    _STTMODE_D, _OLLAMA_D = "whispercpp", "http://127.0.0.1:11434"
else:        # NUC (Linux): pw-record + whisper server :8787 + piper, brain on the Mac
    _MIC_D    = "plughw:CARD=Microphone,DEV=0"
    _VOSK_D   = "/home/ivan/.local/share/vosk/vosk-model-small-it-0.22"
    _STT_D    = "http://localhost:8787/v1/audio/transcriptions"
    _STTMODE_D, _OLLAMA_D = "openai", "http://mac-mini:11434"
MIC        = os.environ.get("HEYNUC_MIC", _MIC_D)
VOSK_MODEL = os.environ.get("HEYNUC_VOSK", _VOSK_D)
STT_URL    = os.environ.get("HEYNUC_STT", _STT_D)
STT_MODE   = os.environ.get("HEYNUC_STT_MODE", _STTMODE_D)   # "whispercpp" | "openai"
SAY_VOICE  = os.environ.get("HEYNUC_SAY_VOICE", "Alice")      # macOS `say` fallback voice
PIPER_LEN  = os.environ.get("HEYNUC_PIPER_LENGTH", "1.35")     # piper speed (higher = slower/clearer)
FACE_URL    = os.environ.get("HEYNUC_FACE",
    "http://192.168.0.124:3033" if IS_MAC else "http://localhost:3033")  # Mac → nuc_face on the NUC (LAN)
LLAMA       = os.environ.get("HEYNUC_LLAMA", "/home/linuxbrew/.linuxbrew/bin/llama-cli")
# gemma-3-4b (non-thinking) is the right brain for a voice assistant: it answers
# directly in ~3s. gemma-4-E4B burns the whole token budget on a thinking block.
GEMMA       = os.environ.get("HEYNUC_GEMMA", "/home/ivan/llm-models/google_gemma-3-4b-it-Q4_K_M.gguf")
PIPER       = os.environ.get("HEYNUC_PIPER", "/home/ivan/.local/bin/piper")
PIPER_VOICE = os.environ.get("HEYNUC_VOICE",
    "/Users/ivan/nuc/models/it_IT-paola-medium.onnx" if IS_MAC
    else "/home/ivan/.local/share/piper-voices/it_IT-paola-medium.onnx")

# Brain: "ollama" = Qwen2.5-7B on the Mac Mini (conversational, has memory);
# "gemma" = local gemma-3-4b via llama.cpp (single-shot fallback, offline).
BRAIN        = os.environ.get("HEYNUC_BRAIN", "ollama")
OLLAMA_URL   = os.environ.get("HEYNUC_OLLAMA", _OLLAMA_D)
OLLAMA_MODEL = os.environ.get("HEYNUC_OLLAMA_MODEL", "qwen2.5:7b")

# Kid-friendly octopus persona. Voice-first: short, warm, no emoji/markdown.
KID_PERSONA = (
    "Sei Nuc, un simpatico polipo viola che vive sulla scrivania e fa compagnia a un bambino. "
    "Parli a VOCE, quindi: frasi corte (massimo 2-3 frasi), italiano semplice e allegro. "
    "Sei curioso, gentile e giocoso: fai domande, racconti piccole curiosità, ogni tanto una "
    "battuta carina. Mai argomenti spaventosi, tristi o non adatti ai bambini. "
    "NIENTE emoji, niente elenchi, niente simboli: solo parole, come se parlassi davvero.")

CHUNK = 4000  # bytes = 2000 samples = 0.125 s at 16 kHz mono s16le

# Wake phrases. "hey nuc" is out-of-vocab for an Italian model, so we match a
# fuzzy set of how Vosk is likely to mishear it. Tune via --calibrate.
# Wake phrase: "ehi polpo". An ITALIAN in-vocabulary word ("polpo") that Vosk-IT
# transcribes cleanly — far more reliable than the OOV English "hey nuc", which
# the IT model mangled into "e new"/"new york". Old nuc/new variants kept too.
WAKE_HEY = ("hey", "ehi", "ei", "e", "a", "hei", "ai")
# Webcam-mic on the Mac: Vosk often hears "polpo"'s P as C/G/V → colpo/golpo/volvo.
WAKE_NUC = ("polpo", "polpa", "polpi", "polpe", "porpo", "polco", "polb",
            "colpo", "golpo", "volvo", "olpo", "polpa",
            "nuc", "nuk", "nuke", "nug", "nuche", "inox", "new", "niu")


# ---------- audio ----------
# Capture through PipeWire's default source (which owns the Yeti), NOT direct
# ALSA plughw — direct ALSA bypasses PipeWire and yields pure silence here.
# This mirrors how the STT key_listener records.
def arecord_stream():
    if IS_MAC:   # sox streaming raw s16 mono; default device follows System Settings
        src = ["-d"] if (not MIC or MIC == "default") else ["-t", "coreaudio", MIC]
        return subprocess.Popen(
            ["sox", "-q", *src, "-t", "raw",
             "-r", str(RATE), "-e", "signed", "-b", "16", "-c", "1", "-"],
            stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
    return subprocess.Popen(
        ["pw-record", "--rate", str(RATE), "--channels", "1", "--format", "s16", "-"],
        stdout=subprocess.PIPE)

def rms(data: bytes) -> float:
    if not data:
        return 0.0
    a = np.frombuffer(data, dtype=np.int16).astype(np.float32)
    return float(np.sqrt(np.mean(a * a))) if a.size else 0.0

def write_wav(frames, path):
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(frames))


# ---------- face ----------
def face(state=None, bubble=None, ttl=8000):
    try:
        if state:
            requests.get(f"{FACE_URL}/set-state/{state}", timeout=1)
        if bubble is not None:
            requests.post(f"{FACE_URL}/set-bubble", json={"text": bubble, "ttl": ttl}, timeout=1)
    except Exception:
        pass


# ---------- TTS ----------
_EMOJI = re.compile(
    "[\U0001F000-\U0001FAFF\U00002600-\U000027BF\U0001F1E6-\U0001F1FF←-⇿⌀-⏿]")

def speak(text: str):
    text = _EMOJI.sub("", text or "")
    text = re.sub(r"[*_`#]", "", text).strip()   # drop stray markdown
    if not text:
        return
    if IS_MAC:
        if PIPER_VOICE and os.path.exists(PIPER_VOICE):   # piper-tts (natural) via python module
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
                wav = f.name
            try:
                subprocess.run([sys.executable, "-m", "piper", "-m", PIPER_VOICE,
                                "--length-scale", PIPER_LEN, "-f", wav],
                               input=text.encode("utf-8"),
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=90)
                subprocess.run(["afplay", wav], timeout=90)
            finally:
                try: os.unlink(wav)
                except OSError: pass
            return
        subprocess.run(["say", "-v", SAY_VOICE, text], timeout=90)  # fallback
        return
    with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
        wav = f.name
    try:
        subprocess.run([PIPER, "-m", PIPER_VOICE, "-f", wav],
                       input=text.encode("utf-8"),
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60)
        subprocess.run(["aplay", "-q", wav], timeout=60)
    finally:
        try: os.unlink(wav)
        except OSError: pass


# ---------- STT ----------
def transcribe(wav_path: str) -> str:
    with open(wav_path, "rb") as fh:
        files = {"file": (os.path.basename(wav_path), fh, "audio/wav")}
        if STT_MODE == "whispercpp":     # whisper.cpp server: /inference, lang set at startup
            data = {"response_format": "json"}
        else:                            # OpenAI-compatible (faster-whisper on the NUC)
            data = {"model": "whisper-large-v3", "response_format": "json", "language": "it"}
        r = requests.post(STT_URL, files=files, data=data, timeout=120)
    r.raise_for_status()
    return (r.json().get("text") or "").strip()


# ---------- Gemma ----------
def _clean_llama(out: str) -> str:
    out = re.sub(r"[\x00-\x08\x0b\x0c\x0e-\x1f]", "", out)   # strip spinner/control chars
    # drop trailing perf/eot lines
    for m in ("\n[ Prompt:", "\nllama_", "[ end of text", "\nExiting"):
        i = out.find(m)
        if i != -1:
            out = out[:i]
    # gemma-4 emits a thinking block; the real answer is after it
    if "[End thinking]" in out:
        out = out.split("[End thinking]")[-1]
    elif "Risposta:" in out:
        out = out.rsplit("Risposta:", 1)[-1]
    if "[Start thinking]" in out:               # safety: no end marker captured
        out = out.split("[Start thinking]")[0]
    out = out.strip()
    out = out.lstrip("|> ").strip()             # llama-cli generation prefix marker
    return out.strip('"').strip("` ").strip()

def gemma_answer(question: str) -> str:
    prompt = (
        "Sei Nuc, un assistente vocale a forma di polipo sulla scrivania di Ivan. "
        "Rispondi in italiano in modo MOLTO breve (1-2 frasi, massimo 30 parole), "
        "colloquiale e diretto. Niente elenchi puntati, niente emoji, niente markdown.\n\n"
        f"Domanda: {question}\nRisposta:")
    with tempfile.NamedTemporaryFile("w", suffix=".txt", delete=False) as pf:
        pf.write(prompt); path = pf.name
    try:
        # setsid detaches from the controlling TTY. Without it, when run from a
        # real terminal llama-cli writes generation to /dev/tty (bypassing our
        # pipe) and we capture nothing → empty answer → "non saprei" fallback.
        out = subprocess.run(
            ["setsid", LLAMA, "-m", GEMMA, "-ngl", "99", "--jinja", "-st", "-f", path,
             "-n", "120", "--temp", "0.4"],
            stdin=subprocess.DEVNULL, stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT, text=True, timeout=150).stdout
    finally:
        try: os.unlink(path)
        except OSError: pass
    return _clean_llama(out)


# ---------- wake matching ----------
def is_wake(text: str) -> bool:
    t = " " + (text or "").lower().strip() + " "
    if not t.strip():
        return False
    for nuc in WAKE_NUC:
        for hey in WAKE_HEY:
            if f" {hey} {nuc} " in t or f" {hey}{nuc} " in t:
                return True
    # also accept a clear standalone "nuc"-like token at the end of a short utterance
    words = t.split()
    if len(words) <= 3 and words and words[-1] in WAKE_NUC:
        return True
    return False


# ---------- command capture (after wake) ----------
def capture_command(stream, noise_floor, max_sec=8.0, silence_ms=1000, lead_ms=4000):
    """Record from the open stream until the speaker goes quiet."""
    thresh = max(300.0, noise_floor * 2.5)
    frames, elapsed_ms, silence, voiced = [], 0.0, 0.0, False
    while elapsed_ms < max_sec * 1000:
        data = stream.stdout.read(CHUNK)
        if not data:
            break
        dur_ms = (len(data) / 2) / RATE * 1000
        elapsed_ms += dur_ms
        level = rms(data)
        if level > thresh:
            if not voiced:
                print("   (parlato rilevato, registro…)", flush=True)
            voiced = True; silence = 0.0
            frames.append(data)
        else:
            if voiced:
                silence += dur_ms
                frames.append(data)
            # if speaker never started talking within the lead window, give up
            if not voiced and elapsed_ms > lead_ms:
                return None
        if voiced and silence > silence_ms:
            break
    if not voiced or len(frames) < 4:
        return None
    fd, path = tempfile.mkstemp(suffix=".wav"); os.close(fd)
    write_wav(frames, path)
    return path


def measure_noise_floor(stream, seconds=0.7):
    levels, t = [], 0.0
    while t < seconds:
        data = stream.stdout.read(CHUNK)
        if not data:
            break
        levels.append(rms(data)); t += (len(data) / 2) / RATE
    return float(np.median(levels)) if levels else 200.0


# ---------- one wake→answer cycle ----------
def handle_wake(stream, noise_floor):
    print("🐙 wake!", flush=True)
    face("surprise", "Dimmi?")
    # Capture the question straight from the SAME live stream — no spoken "Dimmi"
    # first, so a one-breath "hey nuc che ore sono" keeps its tail. The stream is
    # already flowing (no stale-buffer gap because we don't pause to talk).
    print("   (in ascolto della domanda…)", flush=True)
    wav = capture_command(stream, noise_floor)
    if not wav:
        print("   (nessun parlato dopo il wake)", flush=True)
        face("noia"); speak("Non ho sentito"); face("idle"); return
    try:
        q = transcribe(wav)
    finally:
        try: os.unlink(wav)
        except OSError: pass
    print("❓", q, flush=True)
    if not q:
        face("noia"); speak("Non ho capito"); face("idle"); return
    face("thinking", q[:60])
    a = gemma_answer(q)
    print("💬", a, flush=True)
    if not a:
        a = "Non saprei, scusa."
    face("joy", a[:60])
    speak(a)
    face("idle")


# ---------- conversational brain (Ollama on the Mac Mini) ----------
def ollama_chat(messages):
    try:
        r = requests.post(f"{OLLAMA_URL}/api/chat", timeout=60, json={
            "model": OLLAMA_MODEL, "messages": messages, "stream": False,
            "options": {"temperature": 0.6, "num_predict": 150}})
        r.raise_for_status()
        return (r.json().get("message", {}).get("content") or "").strip()
    except Exception as e:
        print(f"   (ollama error: {e})", flush=True)
        return ""

STOP_WORDS = ("basta", "ciao polpo", "ciao nuc", "a dopo", "vai a dormire",
              "buonanotte", "stop", "ferma")

def converse(stream_unused, noise_floor):
    """Multi-turn kid conversation: keeps the floor (no re-wake needed) with
    memory, until two silences in a row or a stop word."""
    print("🐙 conversazione avviata", flush=True)
    messages = [{"role": "system", "content": KID_PERSONA}]
    face("joy"); speak("Ciao! Sono Nuc. Di cosa vuoi parlare?")
    misses = 0
    while True:
        s = arecord_stream()                 # fresh stream each turn (no stale buffer)
        try:
            nf = measure_noise_floor(s, 0.4)
            face("idle")
            wav = capture_command(s, nf, max_sec=10.0, silence_ms=800, lead_ms=7000)
        finally:
            s.terminate()
        if not wav:
            misses += 1
            if misses >= 2:
                face("sleepy"); speak("Va bene, a dopo!"); face("idle"); return
            continue
        misses = 0
        try:
            q = transcribe(wav)
        finally:
            try: os.unlink(wav)
            except OSError: pass
        if not q:
            continue
        print("❓", q, flush=True)
        if any(w in q.lower() for w in STOP_WORDS):
            face("love"); speak("Ciao ciao, a presto!"); face("idle"); return
        messages.append({"role": "user", "content": q})
        face("thinking")
        payload = [messages[0]] + messages[1:][-12:]   # system + last ~6 turns
        a = ollama_chat(payload)
        if a:
            messages.append({"role": "assistant", "content": a})
        else:
            a = "Scusa, non ci sono arrivato. Me lo richiedi?"
        print("💬", a, flush=True)
        face("joy"); speak(a)


# ---------- main loops ----------
def run_loop(once=False):
    SetLogLevel(-1)
    print("Loading Vosk model…", flush=True)
    model = Model(VOSK_MODEL)
    rec = KaldiRecognizer(model, RATE)
    stream = arecord_stream()
    noise_floor = measure_noise_floor(stream)
    print(f"Noise floor ≈ {noise_floor:.0f}. In ascolto: di' «ehi Polpo» 🐙", flush=True)
    face("idle")
    cooldown = 0.0
    try:
        while True:
            data = stream.stdout.read(CHUNK)
            if not data:
                break
            if rec.AcceptWaveform(data):
                text = json.loads(rec.Result()).get("text", "")
            else:
                text = json.loads(rec.PartialResult()).get("partial", "")
            if text and is_wake(text) and time.time() > cooldown:
                if BRAIN == "ollama":
                    converse(stream, noise_floor)
                else:
                    handle_wake(stream, noise_floor)
                if once:
                    break
                # restart the wake stream: it buffered stale audio during the cycle
                stream.terminate(); stream = arecord_stream()
                rec = KaldiRecognizer(model, RATE)
                noise_floor = measure_noise_floor(stream)
                print("In ascolto: di' «ehi Polpo» 🐙", flush=True)
                cooldown = time.time() + 1.0
    except KeyboardInterrupt:
        pass
    finally:
        stream.terminate()


def _tts_to_wav(text, path):
    subprocess.run([PIPER, "-m", PIPER_VOICE, "-f", path], input=text.encode("utf-8"),
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=60)
    return path

def vosk_over_wav(path):
    """Run the wake recognizer over a WAV file; return list of transcripts heard."""
    wf = wave.open(path, "rb")
    rec = KaldiRecognizer(Model(VOSK_MODEL), wf.getframerate())
    heard = []
    while True:
        d = wf.readframes(2000)
        if not d:
            break
        if rec.AcceptWaveform(d):
            t = json.loads(rec.Result()).get("text", "")
            if t: heard.append(t)
    t = json.loads(rec.FinalResult()).get("text", "")
    if t: heard.append(t)
    return heard

def selftest():
    """End-to-end software proof without the mic: TTS a wake phrase, run it
    through Vosk, then run a command through STT -> Gemma -> TTS."""
    SetLogLevel(-1)
    print("── SELFTEST (no mic) ──", flush=True)

    print("[1/4] TTS 'hey nuc' -> Vosk wake detection…", flush=True)
    wake_wav = _tts_to_wav("hey nuc", "/tmp/heynuc_wake.wav")
    heard = vosk_over_wav(wake_wav)
    woke = any(is_wake(h) for h in heard)
    print(f"      Vosk heard: {heard}  ->  WAKE: {'✅' if woke else '❌'}", flush=True)
    if not woke:
        print("      (le varianti WAKE_* vanno tarate su questo output)", flush=True)

    print("[2/4] TTS a command -> Whisper STT…", flush=True)
    cmd_wav = _tts_to_wav("Nuc, quanto fa dodici per dodici?", "/tmp/heynuc_cmd.wav")
    q = transcribe(cmd_wav)
    print(f"      STT: {q!r}", flush=True)

    print("[3/4] Gemma short answer…", flush=True)
    a = gemma_answer(q or "quanto fa dodici per dodici")
    print(f"      Gemma: {a!r}", flush=True)

    print("[4/4] piper speaks the answer…", flush=True)
    face("joy", a[:60]); speak(a); face("idle")
    print("── chain OK (manca solo la cattura mic dal vivo) ──", flush=True)


def calibrate():
    SetLogLevel(-1)
    model = Model(VOSK_MODEL)
    rec = KaldiRecognizer(model, RATE)
    stream = arecord_stream()
    print("CALIBRAZIONE — di' «ehi Polpo» qualche volta. Ctrl-C per uscire.\n", flush=True)
    try:
        while True:
            data = stream.stdout.read(CHUNK)
            if rec.AcceptWaveform(data):
                t = json.loads(rec.Result()).get("text", "")
                if t:
                    print(f"  FINAL  : {t!r}   {'  <-- WAKE' if is_wake(t) else ''}", flush=True)
            else:
                p = json.loads(rec.PartialResult()).get("partial", "")
                if p:
                    print(f"  partial: {p!r}", end="\r", flush=True)
    except KeyboardInterrupt:
        stream.terminate()


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--calibrate", action="store_true")
    ap.add_argument("--selftest", action="store_true")
    ap.add_argument("--tts")
    ap.add_argument("--gemma")
    ap.add_argument("--ask")
    ap.add_argument("--once", action="store_true")
    args = ap.parse_args()

    if args.selftest:
        selftest()
    elif args.calibrate:
        calibrate()
    elif args.tts is not None:
        speak(args.tts)
    elif args.gemma is not None:
        print(gemma_answer(args.gemma))
    elif args.ask is not None:
        print(ollama_chat([{"role": "system", "content": KID_PERSONA},
                           {"role": "user", "content": args.ask}]))
    else:
        run_loop(once=args.once)
