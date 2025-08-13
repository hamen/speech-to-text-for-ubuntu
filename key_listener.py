#!/usr/bin/env python3
"""
Audio Recording Key Listener

This script listens for a specific key press to start audio recording and stops on key release.
In other words, it listens and records when the key is pressed and stops when the key is released.

It is recommended to use a key (I use F16) that is not otherwise used by your system or
applications, otherwise you may experience interference.

For example, suppose you want to use the side mouse button (BTN_SIDE) to trigger speech-to-text.
However, some programs (such as Chrome) already use this button for navigation (e.g., "back").
To avoid conflicts, you can use input-remapper-gtk to remap BTN_SIDE to F16 (which is typically
not used by any program).

This script must be run as root in order to access input devices (e.g., /dev/input/event*).
Running as a regular user will result in permission errors.

To automatically start this key listener on boot, you can use the following crontab entry for root:

* * * * * ps -ef | grep "/home/david/Cursor/speech-to-text/key_listener.py" | grep -v grep > /dev/null || /usr/bin/python3 /home/david/Cursor/speech-to-text/key_listener.py >> /tmp/key_listener.log 2>&1 &

This cron job checks every minute if the key_listener.py script is running. If it is not, it starts the script.
The output and errors are appended to /tmp/key_listener.log.

Usage (as root): python3 key_listener.py

Tested on Ubuntu 24.04.2 LTS

The script assumes that the user has a python virtual environment in /home/david/venv/bin/python3
with the necessary packages installed including evdev, numpy pyautogui soundfile faster-whisper
"""

import logging
import os
import sys
import subprocess
import pwd
import time
import glob
import grp
import shutil


# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s %(levelname)s: %(message)s',
    handlers=[
        logging.StreamHandler(),
        logging.FileHandler('/tmp/key_listener.log')
    ]
)

try:
    from evdev import InputDevice, categorize, ecodes
except ImportError:
    print("Error: evdev library not found. Install in your venv with: pip install evdev")
    sys.exit(1)

# Configuration
# Preferred virtual keyboard name created by input-remapper.
DEVICE_NAME_HINT = "input-remapper keyboard"
# Fallback device path if auto-detection fails (may vary across systems)
DEVICE_PATH = "/dev/input/event12"

# Just a temporary file to store the audio.
AUDIO_FILE = "/tmp/recorded_audio.wav"

# Resolve important paths and user dynamically based on the current system
REPO_DIR = os.path.dirname(os.path.realpath(__file__))

def _detect_foreground_user() -> str:
    """Detect the desktop user when running with elevated privileges.

    Preference order:
    - SUDO_USER (when invoked via sudo)
    - SUDO_UID (resolve to name)
    - LOGNAME / USER env vars
    - Current uid
    """
    sudo_user = os.environ.get("SUDO_USER")
    if sudo_user:
        return sudo_user
    sudo_uid = os.environ.get("SUDO_UID")
    if sudo_uid and sudo_uid.isdigit():
        try:
            return pwd.getpwuid(int(sudo_uid)).pw_name
        except Exception:
            pass
    for var in ("LOGNAME", "USER"):
        value = os.environ.get(var)
        if value and value != "root":
            return value
    try:
        return pwd.getpwuid(os.getuid()).pw_name
    except Exception:
        return "root"

# The user who runs the X server accessing the microphone.
USER = _detect_foreground_user()

# Candidates to discover XAUTHORITY from if not found in ~/.Xauthority
XAUTH_CANDIDATE_PROCESSES = [
    "/usr/bin/ksmserver",            # KDE
    "/usr/bin/gnome-shell",          # GNOME
    "/usr/lib/xorg/Xorg",            # Xorg
    "/usr/lib/xorg/Xwayland",        # XWayland
    "/usr/bin/Xorg",
]

# The script that will process the stored audio and generate text from it.
SPEECHTOTEXT_SCRIPT = os.path.join(REPO_DIR, "speech_to_text.py")

# Your python virtual environment (local venv in this repo)
PYTHON_VENV = os.path.join(REPO_DIR, "venv", "bin", "python3")

def _read_environ_vars_from_process(pid: str) -> dict:
    """Read environment variables from a process's /proc/<pid>/environ.

    Returns a dict of key->value for that process.
    """
    result = {}
    try:
        environ_path = f"/proc/{pid}/environ"
        with open(environ_path, "rb") as f:
            env_vars = f.read().split(b"\0")
            for var in env_vars:
                if not var:
                    continue
                if b"=" in var:
                    k, v = var.split(b"=", 1)
                    try:
                        result[k.decode()] = v.decode()
                    except Exception:
                        continue
    except Exception:
        pass
    return result

def _discover_user_session_env(user: str) -> dict:
    """Try to discover DISPLAY, XDG_SESSION_TYPE, and XAUTHORITY from desktop processes.

    Returns a dict containing any discovered keys.
    """
    discovered = {}
    for candidate in XAUTH_CANDIDATE_PROCESSES:
        try:
            pid = subprocess.check_output(
                ["pgrep", "-u", user, "-f", candidate],
                universal_newlines=True,
            ).strip().split('\n')[0]
        except subprocess.CalledProcessError:
            continue
        env_from_proc = _read_environ_vars_from_process(pid)

        for key in ("DISPLAY", "XDG_SESSION_TYPE", "XAUTHORITY"):
            if key in env_from_proc and key not in discovered:
                discovered[key] = env_from_proc[key]

        # If we have DISPLAY and XDG_SESSION_TYPE we are in good shape; keep XAUTHORITY if present
        if "DISPLAY" in discovered and "XDG_SESSION_TYPE" in discovered:
            break

    return discovered

def setup_environment():
    pw_record = pwd.getpwnam(USER)
    env = os.environ.copy()
    env.update({
        "HOME": pw_record.pw_dir,
        "XDG_CACHE_HOME": os.path.join(pw_record.pw_dir, ".cache"),
        "XDG_RUNTIME_DIR": f"/run/user/{pw_record.pw_uid}",
        "DISPLAY": env.get("DISPLAY", ":0"),
        "YDOTOOL_SOCKET": env.get("YDOTOOL_SOCKET", "/tmp/.ydotool_socket"),
    })

    # Try to discover session-related environment from the desktop user processes if missing
    discovered = _discover_user_session_env(USER)
    if "DISPLAY" in discovered and not env.get("DISPLAY"):
        env["DISPLAY"] = discovered["DISPLAY"]
    if "XDG_SESSION_TYPE" in discovered and not env.get("XDG_SESSION_TYPE"):
        env["XDG_SESSION_TYPE"] = discovered["XDG_SESSION_TYPE"]

    # Log basic session context
    logging.info(
        f"Session context for user '{USER}': DISPLAY={env.get('DISPLAY', '')} "
        f"XDG_SESSION_TYPE={env.get('XDG_SESSION_TYPE', '')}"
    )

    session_type = env.get("XDG_SESSION_TYPE", "").lower()

    # Determine XAUTHORITY. Prefer the user's ~/.Xauthority; otherwise use value discovered
    # from the desktop process. Even on Wayland, Xwayland may require XAUTHORITY.
    if session_type in ("", "x11", "wayland"):
        user_xauth = os.path.join(pw_record.pw_dir, ".Xauthority")
        if os.path.exists(user_xauth):
            env["XAUTHORITY"] = user_xauth
            logging.info(f"Set XAUTHORITY to {user_xauth} (exists)")
        else:
            xauth_from_proc = discovered.get("XAUTHORITY")
            if xauth_from_proc:
                env["XAUTHORITY"] = xauth_from_proc
                logging.info(f"Set XAUTHORITY to {xauth_from_proc} (from desktop process)")
            else:
                logging.warning(
                    "Could not determine XAUTHORITY and ~/.Xauthority does not exist. "
                    "If pyautogui fails to type into the active window, set XAUTHORITY manually."
                )

    return env

def _detect_device_path_by_name(name_hint: str) -> str:
    """Try to find a /dev/input/event* device whose name matches the hint.

    This is robust across reboots where event numbers change.
    """
    try:
        for path in sorted(glob.glob("/dev/input/event*")):
            try:
                dev = InputDevice(path)
            except Exception:
                continue
            if name_hint.lower() in str(getattr(dev, "name", "")).lower():
                return path
    except Exception:
        pass
    # Fallback to parsing /proc/bus/input/devices
    try:
        with open("/proc/bus/input/devices", "r", encoding="utf-8", errors="ignore") as f:
            blocks = f.read().split("\n\n")
        for block in blocks:
            if name_hint.lower() in block.lower():
                for line in block.splitlines():
                    if line.startswith("H:") and "event" in line:
                        parts = line.split()
                        for part in parts:
                            if part.startswith("event"):
                                return f"/dev/input/{part}"
    except Exception:
        pass
    return ""

def resolve_device_path() -> str:
    detected = _detect_device_path_by_name(DEVICE_NAME_HINT)
    if detected:
        logging.info(f"Detected input device for '{DEVICE_NAME_HINT}': {detected}")
        return detected
    logging.warning(f"Could not auto-detect device. Falling back to DEVICE_PATH={DEVICE_PATH}")
    return DEVICE_PATH

def ensure_ydotoold_running(env: dict) -> None:
    """Ensure the ydotool daemon is running (used for Wayland key injection).

    Safe to call on systems without ydotool; it will simply do nothing.
    """
    if not shutil.which("ydotoold"):
        return
    try:
        subprocess.check_call(["pgrep", "-x", "ydotoold"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return
    except subprocess.CalledProcessError:
        pass
    try:
        logging.info("Starting ydotoold daemon")
        socket_path = env.get("YDOTOOL_SOCKET", "/tmp/.ydotool_socket")
        # Ensure any stale socket is removed
        try:
            if os.path.exists(socket_path):
                os.remove(socket_path)
        except Exception:
            pass
        subprocess.Popen([
            "ydotoold",
            "-p", socket_path
        ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, env=env)
        # Wait briefly for the socket and relax permissions so user clients can access it
        for _ in range(50):
            if os.path.exists(socket_path):
                try:
                    os.chmod(socket_path, 0o666)
                except Exception:
                    pass
                break
            time.sleep(0.05)
    except Exception as e:
        logging.warning(f"Could not start ydotoold: {e}")

def main():
    """Main function."""
    # Check if running as root
    if os.geteuid() != 0:
        logging.error("This script must be run as root")
        sys.exit(1)

    # Setup
    env = setup_environment()
    ensure_ydotoold_running(env)
    device_path = resolve_device_path()
    device = InputDevice(device_path)
    recording_process = None

    logging.info(f"Listening for KEY_F16 on {device_path}")

    try:
        for event in device.read_loop():
            if event.type == ecodes.EV_KEY:
                key = categorize(event)

                # Ignore key repeats
                if key.keystate == 2:
                    continue

                if key.keycode == 'KEY_F16':
                    if key.keystate == key.key_down and recording_process is None:
                        # Start recording
                        logging.info("Starting audio recording")
                        # Run arecord as the foreground desktop user so that PipeWire/Pulse can be accessed.
                        try:
                            pw = pwd.getpwnam(USER)
                            uid = pw.pw_uid
                            gid = pw.pw_gid
                            try:
                                groups = os.getgrouplist(USER, gid)  # type: ignore[attr-defined]
                            except Exception:
                                groups = []

                            def demote():
                                try:
                                    if groups:
                                        os.setgroups(groups)
                                    os.setgid(gid)
                                    os.setuid(uid)
                                except Exception as e:
                                    logging.error(f"Failed to setuid/setgid for arecord: {e}")

                            # Prefer PipeWire's pw-record if available; otherwise use arecord via Pulse.
                            if shutil.which("pw-record"):
                                cmd = [
                                    "pw-record",
                                    "--rate", "16000",
                                    "--channels", "1",
                                    "--format", "s16",
                                    AUDIO_FILE
                                ]
                            else:
                                cmd = [
                                    "arecord",
                                    "-D", "pulse",
                                    "-f", "S16_LE",
                                    "-r", "16000",
                                    "-c", "1",
                                    AUDIO_FILE
                                ]

                            recording_process = subprocess.Popen(cmd, env=env, preexec_fn=demote)
                        except Exception as e:
                            logging.error(f"Failed to launch arecord: {e}")
                            recording_process = None
                        logging.info(f"Recording started with PID {recording_process.pid}")

                    elif key.keystate == key.key_up and recording_process:
                        # Stop recording and process
                        logging.info("Stopping audio recording")
                        try:
                            recording_process.terminate()
                            recording_process.wait(timeout=5)
                        except Exception:
                            try:
                                recording_process.kill()
                            except Exception:
                                pass
                        logging.info(f"Recording saved to {AUDIO_FILE}")

                        # Verify that audio was actually captured
                        try:
                            if not os.path.exists(AUDIO_FILE) or os.path.getsize(AUDIO_FILE) == 0:
                                logging.error("No audio captured. Skipping speech-to-text.")
                                recording_process = None
                                continue
                        except Exception:
                            logging.error("Could not verify recorded audio. Skipping speech-to-text.")
                            recording_process = None
                            continue

                        # Process audio
                        logging.info("Running speech-to-text")
                        # Run the speech-to-text script as the user as well
                        try:
                            pw = pwd.getpwnam(USER)
                            uid = pw.pw_uid
                            gid = pw.pw_gid
                            try:
                                groups = os.getgrouplist(USER, gid)  # type: ignore[attr-defined]
                            except Exception:
                                groups = []

                            def demote_stt():
                                try:
                                    if groups:
                                        os.setgroups(groups)
                                    os.setgid(gid)
                                    os.setuid(uid)
                                except Exception as e:
                                    logging.error(f"Failed to setuid/setgid for speech-to-text: {e}")

                            subprocess.run([
                                PYTHON_VENV,
                                SPEECHTOTEXT_SCRIPT,
                                AUDIO_FILE
                            ], env=env, check=True, preexec_fn=demote_stt)

                            # If ydotool exists but could not type as a user, try typing as root using the file output
                            if shutil.which("ydotool") and os.path.exists("/tmp/speech_to_text_output.txt"):
                                text = None
                                try:
                                    with open("/tmp/speech_to_text_output.txt", "r", encoding="utf-8") as f:
                                        text = f.read().strip()
                                except Exception:
                                    text = None
                                # Avoid duplicate typing if the user-space method already succeeded
                                already_typed = os.path.exists("/tmp/speech_to_text_typed.ok")
                                if text and not already_typed:
                                    try:
                                        # Some compositors need a small delay before typing
                                        subprocess.run(["ydotool", "type", text + " "], check=True)
                                    except Exception as e:
                                        logging.warning(f"Root ydotool typing failed: {e}")
                                # Clean the marker file for next run
                                try:
                                    if os.path.exists("/tmp/speech_to_text_typed.ok"):
                                        os.remove("/tmp/speech_to_text_typed.ok")
                                except Exception:
                                    pass
                        except subprocess.CalledProcessError as e:
                            logging.error(f"Speech-to-text failed with exit code {e.returncode}")
                        except Exception as e:
                            logging.error(f"Could not run speech-to-text: {e}")
                        logging.info("Speech-to-text completed")

                        recording_process = None

    except KeyboardInterrupt:
        logging.info("Shutting down due to keyboard interrupt")
        if recording_process:
            recording_process.terminate()
    except Exception as e:
        logging.error(f"Error: {e}")

if __name__ == "__main__":
    main()

