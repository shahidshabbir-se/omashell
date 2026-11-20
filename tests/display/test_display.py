import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[2]
HELPER = ROOT / 'modules/display/display.py'
sys.path.insert(0, str(HELPER.parent))
import display

BASE = display.profile_for('eDP-1', 1920, 1080, 60, 1.3333)
TARGET = display.profile_for('eDP-1', 1280, 720, 59.94, 1.25)
MONITOR = dict(name='eDP-1', width=1920, height=1080, refreshRate=60, scale=1.3333334, x=0, y=0,
               dpmsStatus=True, disabled=False, transform=0, mirrorOf='none', currentFormat='XRGB8888',
               colorManagementPreset='srgb', vrr=False,
               availableModes=['1920x1080@60.00Hz', '1280x720@60.00Hz', '1280x720@59.94Hz',
                               '1280x720@59.94Hz', 'invalid'])


class DisplayTest(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.profile = self.root / 'display.json'
        self.original = (json.dumps(BASE) + '\n').encode()
        self.profile.write_bytes(self.original)
        self.profile.chmod(0o640)
        self.executable = self.root / 'hyprctl'
        shutil.copy(Path(__file__).with_name('fake_hyprctl.py'), self.executable)
        self.executable.chmod(0o700)
        self.env = dict(os.environ, XDG_RUNTIME_DIR=str(self.root), HYPRLAND_INSTANCE_SIGNATURE='fake-laptop',
                        PATH=f"{self.root}:{os.environ['PATH']}", PYTHONDONTWRITEBYTECODE='1')
        self.patch = patch.dict(os.environ, self.env)
        self.patch.start()
        self.addCleanup(self.patch.stop)
        self.hypr = display.Hyprland(str(self.executable), 'fake-laptop')
        self.fake_file = self.root / 'fake-display.json'
        self.fake()

    def fake(self, **kwargs):
        self.fake_file.write_text(json.dumps(dict(instance='fake-laptop', monitor=MONITOR) | kwargs))

    def fake_state(self):
        return json.loads(self.fake_file.read_text())

    def cli(self, *args, executable=HELPER):
        result = subprocess.run([sys.executable, str(executable), *map(str, args)], env=self.env,
                                check=False, capture_output=True, text=True, timeout=7)
        return result.returncode, json.loads(result.stdout)

    def launch(self, target=TARGET, duration=2, fail_save=False, token='a' * 32):
        directory = display.transaction(token)
        directory.mkdir()
        display.status(directory, 'starting', expires=display.now() + 20)
        code = ('import display, json, pathlib, sys; from unittest.mock import patch; '
                f'patch.object(display, "save_profile", side_effect=PermissionError("test failure")).start() if {fail_save!r} else None; '
                f'display.worker(pathlib.Path(sys.argv[1]), display.Hyprland(sys.argv[2], "fake-laptop"), '
                f'pathlib.Path(sys.argv[3]), json.loads(sys.argv[4]), {duration!r})')
        process = subprocess.Popen([sys.executable, '-c', code, directory, self.executable, self.profile,
                                    json.dumps(target)], cwd=HELPER.parent, env=self.env)
        self.addCleanup(self.stop, process)
        return directory, process

    @staticmethod
    def stop(process):
        if process.poll() is None:
            process.terminate()
        process.wait(timeout=12)

    def wait_preview(self, directory):
        end = time.monotonic() + 5
        while time.monotonic() < end:
            current = display.read_status(directory)
            if current['state'] not in ('starting', 'applying'):
                self.assertEqual(current['state'], 'preview', current)
                return
            time.sleep(0.04)
        self.fail('Preview did not become ready')

    def assert_restored(self, directory, process, state='reverted', expected_file=None):
        self.assertEqual(process.wait(timeout=10), 0)
        self.assertEqual(display.read_status(directory)['state'], state, display.read_status(directory))
        self.assertEqual(self.profile.read_bytes(), self.original if expected_file is None else expected_file)
        self.assertTrue(display.same_settings(self.hypr.current('eDP-1')[1], BASE))

    def test_probe_and_advertised_choices_with_compatible_scales(self):
        code, data = self.cli('inspect', self.profile)
        self.assertEqual(code, 0, data)
        self.assertEqual(data['options'][0]['rates'], [59.94, 60])
        self.assertIn(1.333333, data['options'][1]['scales'])
        self.assertNotIn(1.333333, display.scale_options(1366, 768, 1.33333))
        self.assertEqual(data['saved'], BASE)
        self.assertNotIn('applies', self.fake_state())

    def test_timeout_restores_live_baseline_not_saved_profile(self):
        self.profile.write_text(json.dumps(dict(BASE, scale=1)))
        edited = self.profile.read_bytes()
        directory, process = self.launch(duration=0.8)
        self.wait_preview(directory)
        self.assertTrue(display.same_settings(self.hypr.current('eDP-1')[1], TARGET))
        self.assert_restored(directory, process, expected_file=edited)
        display.request(directory, 'keep')
        self.assertEqual(self.profile.read_bytes(), edited)

    def test_cancel_restores_and_does_not_write(self):
        inode = self.profile.stat().st_ino
        directory, process = self.launch()
        self.wait_preview(directory)
        display.request(directory, 'cancel')
        display.request(directory, 'keep')
        self.assert_restored(directory, process)
        self.assertEqual(self.profile.stat().st_ino, inode)

    def test_rotation_is_verified_and_reverted(self):
        target = dict(TARGET, transform=1)
        directory, process = self.launch(target)
        self.wait_preview(directory)
        self.assertEqual(self.hypr.current('eDP-1')[1]['transform'], 1)
        display.request(directory, 'cancel')
        self.assert_restored(directory, process)
        self.assertEqual(self.hypr.current('eDP-1')[1]['transform'], 0)

    def test_rotation_saved_in_managed_lua(self):
        target = dict(TARGET, transform=3)
        self.assertIn('transform = 3', display.render_lua(target))
        self.assertEqual(display.parse_lua(display.render_lua(target).encode()), target)
        with self.assertRaises(display.DisplayError):
            display.validate(dict(target, transform=4))

    def test_text_size_is_separate_from_monitor_profile(self):
        self.env['XDG_STATE_HOME'] = str(self.root / 'state')
        code, data = self.cli('text-size', 14)
        self.assertEqual((code, data), (0, {'size': 14}))
        self.assertEqual((self.root / 'state' / 'omashell' / 'text-size').read_text(), '14\n')
        self.assertEqual(self.profile.read_bytes(), self.original)
        self.assertNotEqual(self.cli('text-size', 100)[0], 0)

    def test_early_keep_is_not_queued(self):
        directory = display.transaction('b' * 32)
        directory.mkdir()
        display.status(directory, 'applying', expires=display.now() + 15)
        display.request(directory, 'keep')
        self.assertEqual(display.decision(directory), '')

    def test_second_preview_cannot_replace_active_transaction(self):
        directory, process = self.launch()
        self.wait_preview(directory)
        other, second = self.launch(token='b' * 32)
        self.assertEqual(second.wait(timeout=5), 0)
        self.assertIn('already running', display.read_status(other)['message'])
        self.assertEqual(len(self.fake_state()['applies']), 1)
        display.request(directory, 'cancel')
        self.assert_restored(directory, process)

    def test_termination_restores_previous_mode(self):
        directory, process = self.launch()
        self.wait_preview(directory)
        process.terminate()
        self.assert_restored(directory, process)

    def test_keep_after_delayed_readback_replaces_atomically(self):
        self.fake(delay=3)
        inode = self.profile.stat().st_ino
        directory, process = self.launch()
        self.wait_preview(directory)
        self.assertNotIn('pending', self.fake_state())
        self.assertTrue(display.same_settings(self.hypr.current('eDP-1')[1], TARGET))
        display.request(directory, 'keep')
        self.assertEqual(process.wait(timeout=8), 0)
        self.assertEqual(display.read_status(directory)['state'], 'kept')
        self.assertEqual(json.loads(self.profile.read_text()), TARGET)
        self.assertEqual(self.profile.stat().st_mode & 0o777, 0o640)
        self.assertNotEqual(self.profile.stat().st_ino, inode)
        self.assertEqual(len(self.fake_state()['applies']), 1)

    def test_external_edit_during_preview_reverts_without_overwriting(self):
        directory, process = self.launch()
        self.wait_preview(directory)
        modified = b'\n' + self.original
        self.profile.write_bytes(modified)
        display.request(directory, 'keep')
        self.assert_restored(directory, process, 'error', modified)
        self.assertIn('changed during preview', display.read_status(directory)['message'])

    def test_save_failure_reverts(self):
        directory, process = self.launch(fail_save=True)
        self.wait_preview(directory)
        display.request(directory, 'keep')
        self.assert_restored(directory, process, 'error')

    def test_mismatched_readback_cannot_be_kept(self):
        self.fake(ignore_first=True)
        directory, process = self.launch(duration=0.6)
        self.assert_restored(directory, process, 'error')
        self.assertIn('verify', display.read_status(directory)['message'])

    def test_compositor_error_after_mutation_still_rolls_back(self):
        self.fake(error_first=True)
        directory, process = self.launch()
        self.assert_restored(directory, process, 'error')
        self.assertEqual(len(self.fake_state()['applies']), 2)

    def test_refuses_legacy_config_and_multiple_outputs(self):
        self.fake(probe='eval is only supported with the lua config manager')
        self.assertEqual(self.cli('inspect', self.profile)[0], 1)
        self.fake(other_monitors=[{'name': 'HDMI-A-1'}])
        directory, process = self.launch()
        self.assertEqual(process.wait(timeout=8), 0)
        self.assertEqual(display.read_status(directory)['state'], 'error')
        self.assertNotIn('applies', self.fake_state())

    def test_refuses_unadvertised_mode(self):
        directory, process = self.launch(dict(TARGET, refreshRate=120))
        self.assert_restored(directory, process, 'error')
        self.assertNotIn('applies', self.fake_state())

    def use_lua(self, profile=BASE, path=None):
        self.profile = path or (self.root / 'display.lua')
        if profile is not None:
            self.profile.write_text(display.render_lua(profile))
            self.profile.chmod(0o644)
        self.original = self.profile.read_bytes() if self.profile.exists() else None
        return self.profile

    def test_standalone_lua_is_deterministic_and_rejects_unmanaged_edits(self):
        text = display.render_lua(BASE)
        self.assertEqual(display.parse_lua(text.encode()), BASE)
        self.assertEqual(text, display.render_lua(dict(reversed(list(BASE.items())))))
        self.assertIn('\nhl.monitor({ output = "eDP-1", mode = "1920x1080@60.000000"', text)
        for edited in ('-- custom\n' + text, text.replace('1.333300', '1.5'),
                       'hl.monitor({ output = "eDP-1", mode = "1920x1080@60", scale = 1 })\n'):
            with self.assertRaises(display.DisplayError):
                display.parse_lua(edited.encode())
        with self.assertRaises(display.DisplayError):
            display.parse_lua(display.LUA_HEADER.encode() + b'{"version":1}\n')

    def test_standalone_inspect_reports_mode_and_existing_file(self):
        self.use_lua()
        code, data = self.cli('inspect', self.profile)
        self.assertEqual(code, 0, data)
        self.assertTrue(data['standalone'])
        self.assertTrue(data['initialized'])
        self.assertEqual(data['saved'], BASE)

    def test_standalone_keep_writes_lua_and_persists_across_reload(self):
        self.use_lua()
        inode = self.profile.stat().st_ino
        directory, process = self.launch()
        self.wait_preview(directory)
        display.request(directory, 'keep')
        self.assertEqual(process.wait(timeout=8), 0)
        self.assertEqual(display.read_status(directory)['state'], 'kept')
        self.assertEqual(self.profile.read_bytes(), display.render_lua(TARGET).encode())
        self.assertEqual(self.profile.stat().st_mode & 0o777, 0o644)
        self.assertNotEqual(self.profile.stat().st_ino, inode)
        # The fragment is self-contained: reloading it restores the saved mode.
        self.assertEqual(display.read_profile(self.profile)[0], TARGET)

    def test_standalone_timeout_and_cancel_leave_lua_untouched(self):
        self.use_lua()
        directory, process = self.launch(duration=0.8)
        self.wait_preview(directory)
        self.assert_restored(directory, process)
        self.assertEqual(self.profile.read_bytes(), self.original)

    def test_standalone_missing_file_is_created_only_by_keep(self):
        self.use_lua(profile=None)
        code, data = self.cli('inspect', self.profile)
        self.assertEqual(code, 0, data)
        self.assertFalse(data['initialized'])
        self.assertEqual({key: data['saved'][key] for key in ('connector', 'width', 'height', 'refreshRate')},
                         {key: BASE[key] for key in ('connector', 'width', 'height', 'refreshRate')})
        directory, process = self.launch()
        self.wait_preview(directory)
        display.request(directory, 'cancel')
        self.assertEqual(process.wait(timeout=10), 0)
        self.assertFalse(self.profile.exists())
        directory, process = self.launch(token='c' * 32)
        self.wait_preview(directory)
        display.request(directory, 'keep')
        self.assertEqual(process.wait(timeout=10), 0)
        self.assertEqual(display.read_status(directory)['state'], 'kept')
        self.assertEqual(self.profile.read_text(), display.render_lua(TARGET))

    def test_standalone_refuses_unknown_file_without_applying(self):
        self.use_lua(profile=None)
        self.profile.write_text('hl.monitor({ output = "eDP-1", mode = "preferred", position = "auto", scale = 1 })\n')
        code, data = self.cli('inspect', self.profile)
        self.assertEqual(code, 1)
        self.assertIn('not an Omashell-managed', data['error'])
        self.assertNotIn('applies', self.fake_state())

    def test_standalone_external_edit_during_preview_is_preserved(self):
        self.use_lua()
        directory, process = self.launch()
        self.wait_preview(directory)
        modified = self.original + b'-- user edit\n'
        self.profile.write_bytes(modified)
        display.request(directory, 'keep')
        self.assert_restored(directory, process, 'error', modified)
        self.assertIn('refusing to overwrite', display.read_status(directory)['message'])

    def test_cli_launches_independent_worker_with_explicit_instance(self):
        launcher = self.root / 'systemd-run'
        launcher.write_text(f'#!{sys.executable}\n'
                            'import os, subprocess, sys\n'
                            'args = sys.argv[1:]\n'
                            'assert "--user" in args and "--service-type=exec" in args\n'
                            'assert "--setenv=XDG_RUNTIME_DIR=" + os.environ["XDG_RUNTIME_DIR"] in args\n'
                            'argv = args[args.index("--") + 1:]\n'
                            'assert argv[2] == "worker" and argv[-1] == "fake-laptop"\n'
                            'subprocess.Popen(argv, start_new_session=True, stdin=subprocess.DEVNULL,\n'
                            '                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)\n')
        launcher.chmod(0o700)
        code, result = self.cli('start', self.profile, json.dumps(TARGET))
        self.assertEqual(code, 0, result)
        token = result['token']
        directory = display.transaction(token)
        self.wait_preview(directory)
        self.assertEqual(self.cli('cancel', token)[0], 0)
        end = time.monotonic() + 5
        while display.read_status(directory)['state'] == 'preview' and time.monotonic() < end:
            time.sleep(0.04)
        self.assertEqual(display.read_status(directory)['state'], 'reverted')
        self.assertEqual(self.profile.read_bytes(), self.original)
        self.assertTrue(display.same_settings(self.hypr.current('eDP-1')[1], BASE))

    def test_unavailable_user_manager_fails_closed(self):
        systemd_run = self.root / 'systemd-run'
        systemd_run.write_text('#!/bin/sh\nexit 1\n')
        systemd_run.chmod(0o700)
        code, result = self.cli('start', self.profile, json.dumps(TARGET))
        self.assertEqual(code, 1)
        self.assertIn('watchdog', result['error'])
        self.assertNotIn('applies', self.fake_state())

    def test_expired_permission_at_atomic_replace_leaves_file_unchanged(self):
        _profile, revision, mode = display.read_profile(self.profile)
        with self.assertRaisesRegex(display.DisplayError, 'expired'):
            display.save_profile(self.profile, TARGET, revision, mode, lambda: False)
        self.assertEqual(self.profile.read_bytes(), self.original)
        self.assertFalse(list(self.profile.parent.glob('.display.json.*')))


if __name__ == '__main__':
    unittest.main()
