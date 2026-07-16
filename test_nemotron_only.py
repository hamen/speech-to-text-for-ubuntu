"""Hermetic tests for the nemotron-only behavior of speech_to_text.transcribe_audio.

The heavy audio deps (numpy / soundfile) are stubbed so the module imports without a GPU
or the real libraries. Run with:  python3 -m unittest test_nemotron_only
"""
import sys
import types
import unittest
from unittest import mock

for _name in ("numpy", "soundfile"):
    if _name not in sys.modules:
        sys.modules[_name] = types.ModuleType(_name)

import speech_to_text as stt  # noqa: E402


class TestNemotronOnly(unittest.TestCase):
    def test_exits_when_server_unavailable(self):
        # No fallback: a None from the server must fail loudly (exit 1), not return.
        with mock.patch.object(stt, "_try_server_transcription", return_value=None):
            with self.assertRaises(SystemExit) as cm:
                stt.transcribe_audio(None, audio_file="/tmp/whatever.wav")
        self.assertEqual(cm.exception.code, 1)

    def test_exits_when_no_audio_file(self):
        with self.assertRaises(SystemExit) as cm:
            stt.transcribe_audio(None, audio_file=None)
        self.assertEqual(cm.exception.code, 1)

    def test_returns_server_result(self):
        with mock.patch.object(stt, "_try_server_transcription", return_value=["ciao"]):
            self.assertEqual(stt.transcribe_audio(None, audio_file="/tmp/x.wav"), ["ciao"])

    def test_no_whisper_fallback_symbol(self):
        # The Whisper engine is gone: the module must not expose WhisperModel anymore.
        self.assertFalse(hasattr(stt, "WhisperModel"))


if __name__ == "__main__":
    unittest.main()
