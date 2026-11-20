import importlib.util
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[2] / 'scripts/setup-display.py'
spec = importlib.util.spec_from_file_location('setup_display', SCRIPT)
setup = importlib.util.module_from_spec(spec)
spec.loader.exec_module(setup)


class DisplayInstallerTest(unittest.TestCase):
    def setUp(self):
        work = self.enterContext(tempfile.TemporaryDirectory())
        self.base = Path(work).resolve()
        self.hypr = self.base / 'hypr' / 'hyprland.lua'
        self.profile = self.hypr.with_name('omashell-display.lua')
        self.marker = self.base / 'omashell' / 'standalone-display'
        self.hypr.parent.mkdir()
        self.original = 'hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })\n'
        self.hypr.write_text(self.original)
        self.hypr.chmod(0o640)

    def test_install_rerun_and_remove_without_losing_profile(self):
        self.assertIsNone(setup.configure(self.base))
        self.assertEqual(self.marker.read_text(), setup.MARKER)
        self.assertEqual(self.hypr.stat().st_mode & 0o777, 0o640)
        self.assertEqual(self.hypr.read_text(), self.original + setup.BLOCK)
        self.assertFalse(self.profile.exists())
        self.profile.write_text('saved monitor settings\n')
        self.assertIsNone(setup.configure(self.base))
        self.assertEqual(self.hypr.read_text(), self.original + setup.BLOCK)
        self.assertIsNone(setup.configure(self.base, remove=True))
        self.assertFalse(self.marker.exists())
        self.assertEqual(self.profile.read_text(), 'saved monitor settings\n')
        self.assertEqual(self.hypr.read_text(), self.original)

    def test_do_not_override_explicit_or_symlinked_configuration(self):
        self.marker.parent.mkdir()
        self.marker.with_name('shell.json').write_text('{"display":{"profilePath":"/some/nix/profile.json"}}')
        self.assertIn('explicit', setup.configure(self.base))
        self.assertFalse(self.marker.exists())
        self.assertEqual(self.hypr.read_text(), self.original)
        source = self.hypr.with_name('external.lua')
        self.hypr.rename(source)
        self.hypr.symlink_to(source)
        self.assertIn('no regular local', setup.configure(self.base))
        self.assertEqual(source.read_text(), self.original)

    def test_do_not_replace_unmanaged_fragment(self):
        self.profile.write_text('user settings\n')
        self.assertIn('without an installer marker', setup.configure(self.base))
        self.assertEqual(self.hypr.read_text(), self.original)
        self.assertEqual(self.profile.read_text(), 'user settings\n')
