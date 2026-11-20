import os
from pathlib import Path
from subprocess import CompletedProcess, TimeoutExpired
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'modules/wallpaper'))
import library
import previews

try:
    from PIL import Image
except ImportError:
    Image = None


class PreviewTest(unittest.TestCase):
    def setUp(self):
        folder = self.enterContext(TemporaryDirectory())
        self.dir = Path(folder)
        self.enterContext(patch.dict(os.environ, HOME=folder, XDG_CACHE_HOME=f'{folder}/cache'))

    @unittest.skipUnless(Image, 'Pillow required')
    def test_cache_is_bounded_by_tier_and_invalidated_on_source_edit(self):
        source = self.dir / 'pic.jpg'
        Image.new('RGB', (2400, 1200), 'red').save(source)
        key = previews.preview_key(source)
        side = previews.make_preview(source, key, 'side')
        center = previews.make_preview(source, key, 'center')
        self.assertEqual(previews.make_preview(source, key, 'side'), side)
        self.assertEqual({side.name, center.name}, {p.name for p in side.parent.glob('*.jpg')})
        with Image.open(side) as result:
            self.assertEqual(result.size, (480, 240))
        with Image.open(center) as result:
            self.assertEqual(result.size, (1600, 800))
        listing = library.list_images({'sources': [str(source)]})
        self.assertEqual(listing[0]['cached'], {'side': side.as_uri(), 'center': center.as_uri()})
        Image.new('RGB', (800, 600), 'blue').save(source)
        self.assertNotEqual(previews.preview_key(source), key)
        self.assertEqual(library.list_images({'sources': [str(source)]})[0]['cached'], {})
        with self.assertRaises(ValueError):
            previews.make_preview(source, key, 'side')

    def test_prune_does_not_touch_unmanaged_files(self):
        old = previews.target_for('1' * 64, 'side')
        new = previews.target_for('2' * 64, 'center')
        old.parent.mkdir(parents=True)
        old.write_bytes(b'old')
        os.utime(old, (0, 0))
        new.write_bytes(b'new')
        unrelated = old.parent / 'some-photo.jpg'
        unrelated.write_bytes(b'user file')
        with patch.object(previews, 'MAX_BYTES', 3):
            previews.prune()
        self.assertFalse(old.exists())
        self.assertTrue(new.exists())
        self.assertEqual(unrelated.read_bytes(), b'user file')

    def test_active_wallpaper_query_uses_correct_output(self):
        stdout = f': DP-4: display, currently displaying: image: {self.dir}/wide # wall.jpg\n'
        stdout += f'eDP-1: display, currently displaying: image: {self.dir}/other.jpg\n'
        with patch.object(library.subprocess, 'run', return_value=CompletedProcess([], 0, stdout)):
            self.assertEqual(library.active_image('DP-4'), str(self.dir / 'wide # wall.jpg'))
            self.assertEqual(library.active_image('eDP-1'), str(self.dir / 'other.jpg'))
        with patch.object(library.subprocess, 'run', side_effect=TimeoutExpired('awww', 0.3)):
            self.assertEqual(library.active_image('DP-4'), '')


if __name__ == '__main__':
    unittest.main()
