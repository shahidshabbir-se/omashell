#!/usr/bin/env python3
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from datetime import datetime, timezone

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).parent))
import state


class WorldClockTests(unittest.TestCase):
    def test_first_run_uses_local_zone_and_spreads_cities(self):
        instant = datetime(2026, 11, 15, 9, tzinfo=timezone.utc)
        expected = {
            'Asia/Karachi': ['Karachi', 'Tokyo', 'Los Angeles', 'New York', 'London'],
            'America/New_York': ['New York', 'London', 'Dubai', 'Tokyo', 'Los Angeles'],
            'Europe/London': ['London', 'Dubai', 'Tokyo', 'Los Angeles', 'New York'],
            'Asia/Tokyo': ['Tokyo', 'Los Angeles', 'New York', 'London', 'Dubai'],
        }
        for zone, names in expected.items():
            with self.subTest(zone=zone):
                self.assertEqual([c['label'] for c in state.defaults(zone, instant)], names)

    def test_saved_cities_and_people_survive_reload(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = dict(os.environ, XDG_STATE_HOME=tmp, TZ='Asia/Tokyo', PYTHONDONTWRITEBYTECODE='1')
            script = str(Path(__file__).with_name('state.py'))
            load = lambda: json.loads(subprocess.check_output([sys.executable, script, 'load'], env=env))
            initial = load()
            self.assertTrue(initial['firstRun'])
            self.assertEqual(initial['home']['zone'], 'Asia/Tokyo')
            saved = {'cities': [{'label': 'Lyon', 'zone': 'Europe/Paris', 'people': ['Alice', '@bob'], 'lat': 45.75, 'lon': 4.85}], 'here': None}
            subprocess.run([sys.executable, script, 'save', json.dumps(saved)], env=env, check=True)
            after = load()
            self.assertFalse(after['firstRun'])
            self.assertEqual(after['cities'], saved['cities'])
            self.assertEqual(after['home']['zone'], 'Asia/Tokyo')

    def test_home_override_only_applies_to_same_system_zone(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = dict(os.environ, XDG_STATE_HOME=tmp, TZ='Asia/Tokyo', PYTHONDONTWRITEBYTECODE='1')
            script = str(Path(__file__).with_name('state.py'))
            saved = {'cities': [], 'here': {'label': 'Osaka', 'zone': 'Asia/Tokyo'}}
            subprocess.run([sys.executable, script, 'save', json.dumps(saved)], env=env, check=True)
            loaded = json.loads(subprocess.check_output([sys.executable, script, 'load'], env=env))
            self.assertEqual(loaded['home']['label'], 'Osaka')
            env['TZ'] = 'Europe/Paris'
            moved = json.loads(subprocess.check_output([sys.executable, script, 'load'], env=env))
            self.assertEqual(moved['home']['label'], 'Paris')
            self.assertIsNone(moved['here'])

    def test_invalid_save_does_not_create_settings(self):
        with tempfile.TemporaryDirectory() as tmp:
            env = dict(os.environ, XDG_STATE_HOME=tmp, PYTHONDONTWRITEBYTECODE='1')
            script = str(Path(__file__).with_name('state.py'))
            result = subprocess.run([sys.executable, script, 'save', '{"cities":[{"label":"bad","zone":"../../etc/passwd"}]}'], env=env, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((Path(tmp) / 'omashell' / 'worldclock.json').exists())


if __name__ == '__main__':
    unittest.main()
