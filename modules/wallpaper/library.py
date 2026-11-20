"""Enumerate personal and optional imported wallpapers, or apply a selection."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from tempfile import NamedTemporaryFile


FORMATS = {'.jpg', '.jpeg', '.png', '.webp', '.bmp', '.gif', '.tif', '.tiff',
           '.avif', '.jxl', '.ico', '.pnm', '.qoi', '.tga', '.dds', '.hdr', '.exr', '.ff'}
THEME = re.compile(r'[a-zA-Z0-9][a-zA-Z0-9_-]*', re.ASCII)
BLOB = re.compile(r'[a-f0-9]{40}', re.ASCII)


def data_dir():
    base = Path(os.environ.get('XDG_DATA_HOME') or '')
    return (base if base.is_absolute() else Path.home() / '.local/share') / 'omashell-wallpapers'


def is_image(path):
    return not path.name.startswith('.') and path.suffix.lower() in FORMATS and path.is_file()


def list_images(config):
    sources = config.get('sources', [str(Path.home() / 'Pictures/Wallpapers')])
    if not isinstance(sources, list) or not all(isinstance(s, str) for s in sources):
        raise ValueError('wallpaper.sources must be an array of paths.')

    def candidates(path):
        try:
            path = Path(path).expanduser()
            if path.is_absolute():
                yield from path.iterdir() if path.is_dir() else (path,)
        except (OSError, RuntimeError):
            pass  # A missing or unreadable source should not hide other sources.

    paths = [path for source in sources for path in candidates(source)]
    paths += [image for blob in candidates(data_dir() / 'omarchy') if BLOB.fullmatch(blob.name)
              for image in candidates(blob)]
    upstream = config.get('omarchy')
    if upstream and isinstance(upstream, dict) and isinstance(upstream.get('source'), str):
        themes = Path(upstream['source']) / 'themes'
        chosen = upstream.get('themes')
        if themes.is_absolute() and (chosen is None or isinstance(chosen, list)):
            paths += [image for theme in candidates(themes)
                      if THEME.fullmatch(theme.name) and (chosen is None or theme.name in chosen)
                      for image in candidates(theme / 'backgrounds')]

    result = []
    seen = set()
    for path in sorted(paths, key=lambda p: (p.name.casefold(), p.name)):
        try:
            if not is_image(path):
                continue
            real = path.resolve(strict=True)
        except (OSError, RuntimeError):
            continue
        if real not in seen:
            result.append({'name': path.name, 'path': str(path), 'url': path.as_uri()})
            seen.add(real)
    return result


def keep_store_image(path):
    """Keep a selected Nix wallpaper usable after flake updates and GC."""
    with path.open('rb') as image:
        digest = hashlib.file_digest(image, 'sha256').hexdigest()
        target = data_dir() / 'applied' / digest / path.name
        if not target.is_file():
            target.parent.mkdir(parents=True, exist_ok=True)
            with NamedTemporaryFile(dir=target.parent, delete=False) as temp:
                staged = Path(temp.name)
                try:
                    image.seek(0)
                    shutil.copyfileobj(image, temp)
                    temp.close()
                    staged.replace(target)
                finally:
                    staged.unlink(missing_ok=True)
        return target


def apply_image(path):
    path = Path(path)
    if not path.is_absolute() or not is_image(path):
        raise ValueError('This wallpaper is no longer available.')
    if path.resolve().is_relative_to('/nix/store'):
        path = keep_store_image(path)
    return subprocess.run(['awww', 'img', '--transition-type', 'fade', '--', str(path)]).returncode


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('action', choices=['list', 'apply'])
    parser.add_argument('value')
    args = parser.parse_args()
    try:
        if args.action == 'apply':
            sys.exit(apply_image(args.value))
        print(json.dumps(list_images(json.loads(args.value))))
    except (OSError, ValueError) as error:
        sys.exit(str(error))
