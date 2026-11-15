#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).parent))
import battery


class PowerTests(unittest.TestCase):
    def test_profile_order_and_active(self):
        text = '* performance:\n    Driver: test\n  balanced:\n  power-saver:\n'
        self.assertEqual(battery.profiles(text), (['power-saver', 'balanced', 'performance'], 'performance'))
        self.assertEqual(battery.profiles(''), ([], ''))

    def test_battery_uses_matching_supply_and_instant_rate(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            device = root / 'BAT1'
            device.mkdir()
            (device / 'power_now').write_text('-10000000')
            (device / 'cycle_count').write_text('222')
            (device / 'charge_control_end_threshold').write_text('80')
            result = battery.battery_reading({'native-path': 'BAT1', 'energy': '20 Wh', 'energy-full': '40 Wh', 'energy-rate': '1 W', 'state': 'discharging'}, root)
            self.assertEqual(result, {'size': '40Wh', 'cycles': '222', 'rate': '10W', 'threshold': '80%', 'chargeEnd': 80, 'time': '2h'})

    def test_current_sysfs_threshold_overrides_stale_upower_value(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            device = root / 'BAT0'
            device.mkdir()
            (device / 'charge_control_start_threshold').write_text('95')
            (device / 'charge_control_end_threshold').write_text('100')
            values = {'native-path': 'BAT0', 'state': 'fully-charged', 'charge-start-threshold': '95%', 'charge-end-threshold': '80%'}
            self.assertEqual(battery.battery_reading(values, root)['threshold'], '95-100%')

    def test_charging_time_uses_charge_limit(self):
        values = {'energy': '20 Wh', 'energy-full': '40 Wh', 'energy-rate': '10 W', 'charge-end-threshold': '80%', 'state': 'charging'}
        self.assertEqual(battery.battery_reading(values)['time'], '1h 12m')

    def test_missing_readings_are_not_fabricated(self):
        self.assertEqual(battery.battery_reading({}), {'size': '—', 'cycles': '—', 'rate': '—', 'threshold': '', 'chargeEnd': None, 'time': ''})

    def test_settings_round_trip(self):
        with tempfile.TemporaryDirectory() as directory:
            env = dict(os.environ, XDG_STATE_HOME=directory, PYTHONDONTWRITEBYTECODE='1')
            script = str(Path(__file__).with_name('battery.py'))
            read = lambda: json.loads(subprocess.check_output([sys.executable, script, 'get'], env=env))['showPercentage']
            self.assertFalse(read())
            subprocess.run([sys.executable, script, 'set', json.dumps({'showPercentage': True, 'profiles': {'ac': 'performance', 'battery': 'balanced'}})], env=env, check=True)
            self.assertTrue(read())
            data = json.loads(subprocess.check_output([sys.executable, script, 'get'], env=env))
            self.assertEqual(data['profiles'], {'ac': 'performance', 'battery': 'balanced'})
            subprocess.run([sys.executable, script, 'set', json.dumps({'showPercentage': False, 'profiles': {}})], env=env, check=True)
            self.assertFalse(read())


if __name__ == '__main__':
    unittest.main()
