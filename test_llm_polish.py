"""Hermetic tests for the optional LLM transcript-polish feature.

These tests never touch a GPU, a network, or the audio dependencies: the heavy imports in
speech_to_text.py (numpy / soundfile) are stubbed in sys.modules before import, and urllib
is mocked. Run with:  python3 -m unittest test_llm_polish
"""
import sys
import types
import socket
import unittest
from unittest import mock

# --- Stub the audio deps so importing speech_to_text does not sys.exit or need a GPU. ---
for _name in ("numpy", "soundfile"):
    if _name not in sys.modules:
        sys.modules[_name] = types.ModuleType(_name)

import speech_to_text as stt  # noqa: E402


def _make_response(body: bytes):
    """A fake urlopen context manager whose .read() returns `body`."""
    resp = mock.MagicMock()
    resp.__enter__.return_value.read.return_value = body
    resp.__exit__.return_value = False
    return resp


def _chat_body(content):
    import json
    return json.dumps({"choices": [{"message": {"content": content}}]}).encode("utf-8")


class TestSanitizePolished(unittest.TestCase):
    def test_strips_leading_label(self):
        self.assertEqual(stt.sanitize_polished("ciao mondo", "Out: ciao mondo"), "ciao mondo")
        self.assertEqual(stt.sanitize_polished("ciao mondo", "Output: ciao mondo"), "ciao mondo")

    def test_does_not_strip_dictated_quotes(self):
        # A leading quote is content, not a leaked label — keep it.
        self.assertEqual(stt.sanitize_polished('lui disse ciao', '"ciao"'), '"ciao"')

    def test_accepts_clean_sentence_unchanged(self):
        out = stt.sanitize_polished("ci vediamo domani in ufficio", "Ci vediamo domani in ufficio.")
        self.assertEqual(out, "Ci vediamo domani in ufficio.")

    def test_accepts_email_collapse(self):
        out = stt.sanitize_polished(
            "manda a luca chiocciola example punto com", "manda a luca@example.com"
        )
        self.assertEqual(out, "manda a luca@example.com")

    def test_accepts_dedup(self):
        self.assertEqual(stt.sanitize_polished("ciao ciao come stai", "Ciao, come stai?"),
                         "Ciao, come stai?")

    def test_accepts_percentage_conversion(self):
        self.assertEqual(stt.sanitize_polished("dieci per cento di sconto", "10% di sconto"),
                         "10% di sconto")

    def test_accepts_accent_fix(self):
        # venerdì folds to venerdi -> same word, allowed.
        self.assertEqual(stt.sanitize_polished("ci vediamo venerdi", "Ci vediamo venerdì."),
                         "Ci vediamo venerdì.")

    def test_accepts_dictated_non_posso(self):
        # "non posso" is legitimate dictation, not refusal boilerplate.
        self.assertEqual(stt.sanitize_polished("non posso venire domani", "Non posso venire domani."),
                         "Non posso venire domani.")

    def test_rejects_empty(self):
        self.assertIsNone(stt.sanitize_polished("ciao", ""))
        self.assertIsNone(stt.sanitize_polished("ciao", "   "))
        self.assertIsNone(stt.sanitize_polished("ciao", None))

    def test_rejects_empty_original(self):
        self.assertIsNone(stt.sanitize_polished("", "qualcosa"))

    def test_rejects_added_word(self):
        # A word absent from the source ("quindi") — rejected even within length bounds.
        self.assertIsNone(stt.sanitize_polished("pago al mese", "pago quindi mese"))

    def test_rejects_changed_word(self):
        # Substituting a word (e.g. a mis-heard number) is caught: 'trenta' not in source.
        self.assertIsNone(stt.sanitize_polished("pago venti euro", "pago trenta euro"))

    def test_rejects_duplicated_word(self):
        # multiset containment: an ADDED repetition is rejected.
        self.assertIsNone(stt.sanitize_polished("ciao come stai", "ciao ciao come stai"))

    def test_rejects_runaway_length(self):
        self.assertIsNone(stt.sanitize_polished("ok", "ok " * 50))

    def test_rejects_refusal_boilerplate(self):
        # Length-neutral so this exercises the word-multiset guard, not the length cap:
        # the refusal's words ("non", "riesco", "farlo") aren't in the source.
        self.assertIsNone(stt.sanitize_polished(
            "trascrivi questo testo per favore", "non riesco a farlo"))


class TestPolishWithLlm(unittest.TestCase):
    def test_happy_path(self):
        with mock.patch("urllib.request.urlopen", return_value=_make_response(_chat_body("Ciao."))):
            self.assertEqual(stt.polish_with_llm("ciao"), "Ciao.")

    def test_timeout_returns_none(self):
        with mock.patch("urllib.request.urlopen", side_effect=socket.timeout("slow")):
            self.assertIsNone(stt.polish_with_llm("ciao"))

    def test_urlerror_returns_none(self):
        import urllib.error
        with mock.patch("urllib.request.urlopen", side_effect=urllib.error.URLError("refused")):
            self.assertIsNone(stt.polish_with_llm("ciao"))

    def test_httperror_returns_none(self):
        import urllib.error
        err = urllib.error.HTTPError("http://x", 500, "boom", {}, None)
        with mock.patch("urllib.request.urlopen", side_effect=err):
            self.assertIsNone(stt.polish_with_llm("ciao"))

    def test_malformed_json_returns_none(self):
        with mock.patch("urllib.request.urlopen", return_value=_make_response(b"not json")):
            self.assertIsNone(stt.polish_with_llm("ciao"))

    def test_empty_choices_returns_none(self):
        import json
        body = json.dumps({"choices": []}).encode("utf-8")
        with mock.patch("urllib.request.urlopen", return_value=_make_response(body)):
            self.assertIsNone(stt.polish_with_llm("ciao"))

    def test_non_string_content_returns_none(self):
        with mock.patch("urllib.request.urlopen", return_value=_make_response(_chat_body(123))):
            self.assertIsNone(stt.polish_with_llm("ciao"))

    def test_invalid_timeout_env_falls_back(self):
        with mock.patch.dict("os.environ", {"STT_LLM_POLISH_TIMEOUT": "not-a-number"}):
            with mock.patch("urllib.request.urlopen",
                            return_value=_make_response(_chat_body("Ok."))) as m:
                self.assertEqual(stt.polish_with_llm("ok"), "Ok.")
                self.assertEqual(m.call_args.kwargs["timeout"], 2.0)

    def test_truncated_response_returns_none(self):
        import json
        body = json.dumps({"choices": [{"finish_reason": "length",
                                        "message": {"content": "troncato a meta"}}]}).encode("utf-8")
        with mock.patch("urllib.request.urlopen", return_value=_make_response(body)):
            self.assertIsNone(stt.polish_with_llm("un testo qualsiasi"))

    def test_input_too_long_skips_without_network(self):
        long_text = "a " * (stt.STT_LLM_POLISH_MAX_CHARS + 10)
        with mock.patch("urllib.request.urlopen") as m:
            self.assertIsNone(stt.polish_with_llm(long_text))
            m.assert_not_called()


class TestDefaults(unittest.TestCase):
    def test_polish_off_by_default(self):
        # With STT_LLM_POLISH unset at import time, the feature is off — the main() path
        # is gated by `if STT_LLM_POLISH:` so no network call happens by default.
        self.assertFalse(stt.STT_LLM_POLISH)


if __name__ == "__main__":
    unittest.main()
