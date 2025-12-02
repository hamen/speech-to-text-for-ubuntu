import unittest
import time
from unittest.mock import MagicMock
from key_listener import KeyListenerLogic

class TestKeyLogic(unittest.TestCase):
    def setUp(self):
        self.on_start = MagicMock()
        self.on_stop = MagicMock()
        self.logic = KeyListenerLogic(self.on_start, self.on_stop)

    def test_f16_normal_behavior(self):
        # Press F16
        self.logic.handle_event('KEY_F16', 1, time.time())
        self.on_start.assert_called_once()
        self.assertTrue(self.logic.recording)
        
        # Release F16
        self.logic.handle_event('KEY_F16', 0, time.time())
        self.on_stop.assert_called_once()
        self.assertFalse(self.logic.recording)

    def test_super_single_press_does_nothing(self):
        t = time.time()
        # Press Super
        self.logic.handle_event('KEY_LEFTMETA', 1, t)
        self.on_start.assert_not_called()
        
        # Release Super
        self.logic.handle_event('KEY_LEFTMETA', 0, t + 0.1)
        self.on_start.assert_not_called()
        self.on_stop.assert_not_called()

    def test_super_double_press_activates(self):
        t = time.time()
        
        # Press 1
        self.logic.handle_event('KEY_LEFTMETA', 1, t)
        # Release 1
        self.logic.handle_event('KEY_LEFTMETA', 0, t + 0.1)
        
        # Press 2 (within 0.5s)
        self.logic.handle_event('KEY_LEFTMETA', 1, t + 0.3)
        
        self.on_start.assert_called_once()
        self.assertTrue(self.logic.recording)
        
        # Release 2
        self.logic.handle_event('KEY_LEFTMETA', 0, t + 1.0)
        self.on_stop.assert_called_once()
        self.assertFalse(self.logic.recording)

    def test_super_slow_double_press_ignores(self):
        t = time.time()
        
        # Press 1
        self.logic.handle_event('KEY_LEFTMETA', 1, t)
        # Release 1
        self.logic.handle_event('KEY_LEFTMETA', 0, t + 0.1)
        
        # Press 2 (after 1.0s, > threshold)
        self.logic.handle_event('KEY_LEFTMETA', 1, t + 1.2)
        
        self.on_start.assert_not_called()
        self.assertFalse(self.logic.recording)

    def test_ctrl_double_press_activates(self):
        t = time.time()
        
        # Press 1
        self.logic.handle_event('KEY_LEFTCTRL', 1, t)
        # Release 1
        self.logic.handle_event('KEY_LEFTCTRL', 0, t + 0.1)
        
        # Press 2 (within 0.5s)
        self.logic.handle_event('KEY_LEFTCTRL', 1, t + 0.3)
        
        self.on_start.assert_called_once()
        self.assertTrue(self.logic.recording)
        
        # Release 2
        self.logic.handle_event('KEY_LEFTCTRL', 0, t + 1.0)
        self.on_stop.assert_called_once()
        self.assertFalse(self.logic.recording)

    def test_interleaved_keys_no_stop(self):
        """Ensure pressing other keys doesn't stop recording if F16 started it."""
        # Start with F16
        self.logic.handle_event('KEY_F16', 1, time.time())
        self.on_start.assert_called_once()
        self.assertTrue(self.logic.recording)
        
        # Press Super (should be ignored)
        self.logic.handle_event('KEY_LEFTMETA', 1, time.time())
        self.assertTrue(self.logic.recording)
        
        # Release Super (should be ignored)
        self.logic.handle_event('KEY_LEFTMETA', 0, time.time())
        self.assertTrue(self.logic.recording)
        
        # Release F16 (Stops)
        self.logic.handle_event('KEY_F16', 0, time.time())
        self.on_stop.assert_called_once()
        self.assertFalse(self.logic.recording)

if __name__ == '__main__':
    unittest.main()
