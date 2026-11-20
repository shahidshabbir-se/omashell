import hashlib
import io
import os
from pathlib import Path
import sys
from tempfile import TemporaryDirectory
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / 'modules/wallpaper'))
import import_omarchy
import library


def entry(name, payload=b'image', mode='100644'):
    blob = hashlib.sha1(f'blob {len(payload)}\0'.encode() + payload).hexdigest()
    return {'path': name, 'sha': blob, 'size': len(payload), 'mode': mode, 'type': 'blob'}


class WallpaperTest(unittest.TestCase):
    def setUp(self):
        temp = self.enterContext(TemporaryDirectory())
        self.root = Path(temp)
        self.enterContext(patch.dict(os.environ, HOME=temp, XDG_DATA_HOME=f'{temp}/data'))

    def make(self, relative):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b'image')
        return str(path)

    def test_unified_library_single_files_folders_and_pinned_themes(self):
        personal = self.make('Pictures/Wallpapers/local.webp')
        other = self.make('other # image.JPG')
        self.make('Pictures/Wallpapers/no.sh')
        self.make('Pictures/Wallpapers/subfolder/ignored.png')
        managed = self.make('data/omashell-wallpapers/omarchy/' + 'c'*40 + '/downloaded.png')
        nord = self.make('checkout/themes/nord/backgrounds/nord.webp')
        self.make('checkout/themes/nord/backgrounds/video.mp4')
        night = self.make('checkout/themes/tokyo-night/backgrounds/tokyo.png')
        config = {'sources': ['~/Pictures/Wallpapers', '~/other # image.JPG', '~/missing', personal],
                  'omarchy': {'source': str(self.root / 'checkout'), 'themes': ['nord']}}
        paths = lambda conf: {item['path'] for item in library.list_images(conf)}
        self.assertEqual(paths(config), {personal, other, managed, nord})
        config['omarchy']['themes'] = None
        self.assertEqual(paths(config), {personal, other, managed, nord, night})
        self.assertEqual(paths({}), {personal, managed})
        self.assertEqual(paths({'sources': []}), {managed})

    def test_catalog_and_installer_selection_ignore_scripts_links_and_video(self):
        entries = [entry('themes/nord/backgrounds/pic.webp'), entry('themes/nord/backgrounds/intro.mp4'),
                   entry('themes/nord/backgrounds/looks-like-image.png', mode='120000'),
                   entry('themes/nord/installer.png'), entry('themes/tokyo-night/backgrounds/theme.jpg')]
        revision, themes = import_omarchy.catalog({'sha': 'a'*40, 'truncated': False, 'tree': entries})
        self.assertEqual(revision, 'a'*40)
        self.assertEqual(themes, {'nord': [entries[0]], 'tokyo-night': [entries[-1]]})
        self.assertEqual(import_omarchy.choose(themes, '2,nord,2'), ['tokyo-night', 'nord'])
        self.assertEqual(import_omarchy.choose(themes, 'all'), list(themes))
        self.assertEqual(import_omarchy.choose(themes, ''), [])
        with self.assertRaises(ValueError):
            import_omarchy.choose(themes, 'missing')

    def test_import_verifies_bytes_and_preserves_downloads(self):
        first = entry('themes/nord/backgrounds/spaces #.webp')
        renamed = entry('themes/nord/backgrounds/new-name.webp')
        bad = entry('themes/nord/backgrounds/bad.webp', b'other')
        destination = library.data_dir() / 'omarchy'
        with patch.object(import_omarchy, 'request', side_effect=lambda _: io.BytesIO(b'image')) as fetch:
            self.assertEqual(import_omarchy.download('a'*40, [first, renamed], destination), 1)
            self.assertTrue(fetch.call_args.args[0].endswith('/spaces%20%23.webp'))
            self.assertEqual(import_omarchy.download('b'*40, [renamed], destination), 0)
            with self.assertRaises(ValueError):
                import_omarchy.download('b'*40, [bad], destination)
        self.assertEqual([item['name'] for item in library.list_images({'sources': []})], ['spaces #.webp'])

    def test_apply_uses_native_random_transition(self):
        path = self.make('wallpaper #1.webp')
        with patch.object(library.subprocess, 'run') as run:
            run.return_value.returncode = 0
            self.assertEqual(library.apply_image(path), 0)
        run.assert_called_once_with(['awww', 'img', '--transition-type', 'random', '--', path])

    def test_caching_a_selected_store_image_makes_a_stable_copy(self):
        original = Path(self.make('source/file.webp'))
        cached = library.keep_store_image(original)
        self.assertEqual(library.keep_store_image(original), cached)
        original.unlink()
        self.assertEqual(cached.read_bytes(), b'image')


if __name__ == '__main__':
    unittest.main()
