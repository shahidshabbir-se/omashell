from pathlib import Path
import sys
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'modules/display'))
import backlight

DEVICE = 'amdgpu_bl1,backlight,16384,25%,65535'


class BacklightTest(unittest.TestCase):
    @patch.object(backlight, 'brightnessctl', return_value=DEVICE)
    def test_read_does_not_write(self, ctl):
        self.assertEqual(backlight.brightness(), 25)
        ctl.assert_called_once_with('--list')

    @patch.object(backlight, 'brightnessctl', side_effect=[DEVICE, '', 'amdgpu_bl1,backlight,32768,50%,65535'])
    def test_write_targets_the_detected_backlight_then_reads_back(self, ctl):
        self.assertEqual(backlight.brightness(50), 50)
        self.assertEqual(ctl.call_args_list[1].args, ('--device=amdgpu_bl1', '--min-value=1', 'set', '50%'))
        self.assertEqual(ctl.call_args_list[2].args, ('--device=amdgpu_bl1', 'info'))

    @patch.object(backlight, 'brightnessctl', return_value=DEVICE + '\n' + DEVICE)
    def test_ambiguous_devices_fail_closed(self, ctl):
        with self.assertRaisesRegex(backlight.BacklightError, 'unambiguous'):
            backlight.brightness(1)
        ctl.assert_called_once_with('--list')

    @patch.object(backlight, 'brightnessctl', return_value=DEVICE)
    def test_zero_brightness_cannot_be_written(self, ctl):
        with self.assertRaisesRegex(backlight.BacklightError, 'between 1% and 100%'):
            backlight.brightness(0)
        ctl.assert_called_once_with('--list')


if __name__ == '__main__':
    unittest.main()
