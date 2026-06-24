# Fast push-to-talk speech-to-text for Ubuntu

## ✨ What's New — `parakeet_stt_server.py` LLM post-processing

> Added in [#2](https://github.com/CDNsun/speech-to-text-for-ubuntu/pull/2) — optional, off by default unless you use Parakeet backend.

Two quality-of-life improvements for the [Parakeet persistent server](parakeet_stt_server.py):

**1. LLM post-processing pass**
After Parakeet transcribes, a tiny local LLM (Qwen2.5-0.5B-Instruct, ~470 MB) runs over the text and:
- Fixes obvious speech-to-text garbles (wrong homophones, impossible words)
- Adds `?` when the sentence starts with a question word (`come`, `cosa`, `what`, `how`, etc.)
- Does **not** rephrase — a safety guard rejects the LLM output if word count changes by >20%

Runs fully on GPU via `llama-cpp-python`. Adds ~150–250 ms on an RTX 4070 — negligible for push-to-talk.

```bash
# install deps
pip install llama-cpp-python --extra-index-url https://abetlen.github.io/llama-cpp-python/whl/cu124
# download model (~470 MB)
python -c "import os; from huggingface_hub import hf_hub_download; hf_hub_download('Qwen/Qwen2.5-0.5B-Instruct-GGUF', 'qwen2.5-0.5b-instruct-q4_k_m.gguf', local_dir=os.path.expanduser('~/models/stt-postprocess'))"
```

Environment variables:

| Variable | Default | Description |
|---|---|---|
| `STT_LLM_POSTPROCESS` | `1` | Set to `0` to disable |
| `STT_LLM_MODEL` | `~/models/stt-postprocess/qwen2.5-0.5b-instruct-q4_k_m.gguf` | Path to GGUF model |
| `STT_LLM_GPU_LAYERS` | `99` | GPU layers (set to `0` for CPU-only) |

**2. 300 ms silence padding**
Each recording gets 300 ms of silence appended before being passed to Parakeet. This prevents the last word from being clipped when the push-to-talk key is released while still speaking — a common issue with tight key-release timing.

---

This project gives Ubuntu a practical push-to-talk speech-to-text workflow. You hold a key, speak, release the key, and the transcript is typed into the currently focused application.

The main goal is low-latency local transcription that is still usable on ordinary hardware. In practice, this setup can be fast enough for live work even on a laptop without a dedicated GPU. On CPU-only hardware, transcription can still complete in under two seconds, which makes it practical for live communication with an AI agent or any other text interface without typing.

The project is built from three parts. `servers/key_listener.py` listens for a hotkey, starts recording on key press, and stops on key release. `servers/speech_to_text_server.py` runs a local Unix socket server and performs speech-to-text with faster-whisper. `scripts/speech_to_text_client.py` sends the recorded audio to the server, receives the transcript, optionally copies it to the clipboard, and types the text with `xdotool`.

Tested on Kubuntu 24.04 LTS, Kali 2026.1, Ubuntu 24.04 LTS

## How it works

1. You press and hold a hotkey, for example `F16`
2. `key_listener.py` starts recording audio with `arecord`
3. You release the key
4. The key listener calls `speech_to_text_client.py`
5. The client sends the audio file path and language to `speech_to_text_server.py`
6. The server loads the audio and runs faster-whisper
7. The client receives the transcript
8. The transcript is optionally copied to the clipboard and typed into the active window

## Installation on a fresh Ubuntu system

Start by installing the required system packages:

```bash
sudo apt update
sudo apt install -y \
  git \
  python3 \
  python3-venv \
  libsndfile1 \
  xdotool \
  xclip \
  wl-clipboard \
  input-remapper \
  alsa-utils \
  python3-evdev \
  evtest
```

`xdotool` is used to type the transcript into the focused window. `xclip` is used for clipboard copy on X11, while `wl-clipboard` provides clipboard support on Wayland. `input-remapper` is strongly recommended for creating a reliable trigger key such as `F16`, and `evtest` helps you find the correct input device path. `libsndfile1` is required by the Python `soundfile` package.

Clone the repository. The examples below assume the project is stored in `/home/david/speech-to-text-for-ubuntu` and the virtual environment is `/home/david/venv`. If your username or paths differ, adjust the configuration values in the scripts accordingly.

```bash
cd /home/david
git clone https://github.com/CDNsun/speech-to-text-for-ubuntu.git
cd /home/david/speech-to-text-for-ubuntu
```

Then create a Python virtual environment and install the Python dependencies from `requirements.txt`:

```bash
python3 -m venv /home/david/venv
/home/david/venv/bin/pip install --upgrade pip
/home/david/venv/bin/pip install -r /home/david/speech-to-text-for-ubuntu/requirements.txt
```

The Python packages used by the project are `numpy`, `soundfile`, and `faster-whisper`.

## Configure input-remapper

This project is designed around using `input-remapper`. Technically, it is possible to trigger the workflow in other ways, but in practice `input-remapper` is the recommended way to use it. It gives you a dedicated push-to-talk key, avoids conflicts with keys or mouse buttons already used by your desktop or applications, and makes the workflow much more comfortable for daily use.

A typical setup is to map one trigger to `F16` and, if needed, a second trigger to `F17`. This works especially well when using side mouse buttons. For example, a mouse button such as `BTN_SIDE` can be remapped to `F16`, which avoids conflicts with browser navigation and other default actions.

If you want to identify the correct input device first, run:

```bash
sudo evtest
```

When `input-remapper` is in use, a typical device may look like this:

```text
/dev/input/event15: input-remapper keyboard
```

## Configure the key listener

Open `servers/key_listener.py` and review the configuration values near the top of the file.

In particular, you will usually want to adjust:

- `DEVICE_PATH`, for example `/dev/input/event15`
- `USER`, for example `david`
- `USER_DISPLAY`, usually `:0`
- `USER_WAYLAND_DISPLAY`, empty for X11 and something like `wayland-0` for Wayland
- `STATIC_XAUTHORITY`, if needed
- `PROCESS_FOR_XAUTH_COPY`, default example `/usr/bin/ksmserver`
- `SPEECHTOTEXT_SCRIPT`, the path to `scripts/speech_to_text_client.py`
- `PRIMARY_LANGUAGE`, default `en`
- `SECONDARY_LANGUAGE`, optional, default `cs`

The key listener must be run as root because it needs access to `/dev/input/event*`.

## Configure the speech-to-text server

Open `servers/speech_to_text_server.py` and review the Whisper configuration.

The most important settings are:

- `PRIMARY_LANGUAGE_MODEL`, default `small`
- `SECONDARY_LANGUAGE_MODEL`, default `medium`
- `SECONDARY_MODEL_LANGUAGES`, default `("cs",)`
- `COMPUTE_TYPE`, default `int8`
- `WHISPER_CPU_THREADS`, default `8`
- `INITIAL_PROMPT_EN`
- `INITIAL_PROMPT_CS`

The server supports a primary model for the default path and an optional secondary model for selected languages. This allows you to keep the common case fast while still using a larger model where accuracy matters more.

## Why there are two buttons

The second button is optional, but it is a very practical part of the design.

One common setup is to use one button for English and another button for (for example) Czech. In that case, the selected button already tells the system which language is expected, so the correct language code can be passed directly to Whisper. That means the model does not need to rely on language autodetection first.

It is also useful because different languages may benefit from different model sizes. A smaller model may already be fast and accurate enough for English, while a larger model may give better results for Czech. Since larger models are usually slower, this split lets you keep one fast path and one higher-quality path.

Because of that, the two-button design is useful not only as a two-language setup, but also as a two-mode setup. One path can be optimized for speed, while the other can be optimized for accuracy.

By default, the primary model is used for most languages, and the secondary model is used only for the languages listed in `SECONDARY_MODEL_LANGUAGES`.

## Optional clipboard behavior

If you want the transcript to be copied to the clipboard before typing, leave `COPY_TO_CLIPBOARD` enabled in `scripts/speech_to_text_client.py`:

```python
COPY_TO_CLIPBOARD = "yes"
```

If you do not want clipboard copy, set it to an empty string:

```python
COPY_TO_CLIPBOARD = ""
```

## Usage

Start the speech-to-text server as your normal desktop user:

```bash
/home/david/venv/bin/python3 /home/david/speech-to-text-for-ubuntu/servers/speech_to_text_server.py
```

This starts a Unix socket server at:

```text
/tmp/stt_server.sock
```

Then start the key listener as root:

```bash
sudo python3 /home/david/speech-to-text-for-ubuntu/servers/key_listener.py
```

Once both processes are running, focus the text field where you want the transcript to appear, press and hold your trigger key, speak, and release the key. The recorded audio is transcribed and the resulting text is typed into the currently focused window.

By default, `F16` is used for the primary language and primary model path, while `F17` can be used for the secondary language and secondary model path. If `SECONDARY_LANGUAGE` is empty, only `F16` is used.

Typing is implemented with `xdotool`, which is primarily an X11-oriented solution. Clipboard copy supports both X11 and Wayland, but automatic typing may be more reliable in X11 sessions.

## Start automatically on boot

The project comments include simple cron-based startup examples.

To start the server automatically as your desktop user, add this to your user crontab:

```cron
* * * * * ps -ef | grep "speech-to-text-for-ubuntu/servers/speech_to_text_server.py" | grep -v grep > /dev/null || /home/david/venv/bin/python3 /home/david/speech-to-text-for-ubuntu/servers/speech_to_text_server.py > /dev/null 2>&1 &
```

Edit the user crontab with:

```bash
crontab -e
```

To start the key listener automatically as root, add this to the root crontab:

```cron
* * * * * ps -ef | grep "speech-to-text-for-ubuntu/servers/key_listener.py" | grep -v grep > /dev/null || /usr/bin/python3 /home/david/speech-to-text-for-ubuntu/servers/key_listener.py > /dev/null 2>&1 &
```

Edit the root crontab with:

```bash
sudo crontab -e
```

## Logs

The scripts write logs to `/tmp/stt_server.log`, `/tmp/stt_client.log`, and `/tmp/stt_key_listener.log`. These are useful when checking whether the workflow is running correctly or when tuning performance.
