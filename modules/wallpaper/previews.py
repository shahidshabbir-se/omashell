"""Bounded on-disk previews, independent of the wallpaper setter."""
import hashlib
import json
import io
import os
from pathlib import Path
import shutil
import subprocess
import sys
from tempfile import NamedTemporaryFile
import time


SIZES = {'side': (480, 360), 'center': (1600, 1080)}
MAX_BYTES = 384 * 1024 * 1024


def cache_dir():
    base = Path(os.environ.get('XDG_CACHE_HOME') or '')
    return (base if base.is_absolute() else Path.home() / '.cache') / 'omashell/wallpaper-previews-v1'


def preview_key(path):
    real = path.resolve(strict=True)
    stat = real.stat()
    parts = (os.fsencode(real), str(stat.st_size).encode(), str(stat.st_mtime_ns).encode())
    return hashlib.sha256(b'\0'.join(parts)).hexdigest()


def target_for(key, tier):
    return cache_dir() / f'{key}-{tier}.jpg'


def prune():
    root = cache_dir()
    stamp = root / '.pruned'
    try:
        if time.time() - stamp.stat().st_mtime < 60:
            return
    except FileNotFoundError:
        pass
    # Only touch our own preview files. Missing files are normal with concurrent workers.
    files = []
    for path in root.glob('*.jpg'):
        if len(path.stem.split('-')[0]) != 64 or path.stem.rsplit('-', 1)[-1] not in SIZES:
            continue
        try:
            stat = path.stat()
            files.append((max(stat.st_atime_ns, stat.st_mtime_ns), stat.st_size, path))
        except FileNotFoundError:
            pass
    total = sum(entry[1] for entry in files)
    for _, size, path in sorted(files):
        if total <= MAX_BYTES:
            break
        path.unlink(missing_ok=True)
        total -= size
    stamp.touch()


def make_preview(path, key, tier):
    if preview_key(path) != key:
        raise ValueError('Wallpaper changed since it was listed.')
    target = target_for(key, tier)
    if target.is_file():
        return target
    # Pillow is only needed on a cache miss; enumeration and apply stay lightweight.
    from PIL import Image, ImageOps
    size = SIZES[tier]
    with Image.open(path) as im:
        # JPEG can decode at subsampled resolution rather than creating a huge original buffer.
        im.draft('RGB', (max(size), max(size)))
        orientation = im.getexif().get(274, 1)
        decoder = shutil.which('dwebp') if im.format == 'WEBP' and orientation == 1 and not getattr(im, 'is_animated', False) else None
        if decoder:
            # libwebp can resize during decode instead of allocating a full original.
            scale = min(1, size[0] / im.width, size[1] / im.height)
            width, height = max(1, round(im.width * scale)), max(1, round(im.height * scale))
            try:
                ppm = subprocess.run([decoder, '-quiet', '-mt', '-resize', str(width), str(height),
                                      '-ppm', str(path), '-o', '-'], check=True, stdout=subprocess.PIPE,
                                     stderr=subprocess.DEVNULL, timeout=15).stdout
                with Image.open(io.BytesIO(ppm)) as preview:
                    out = preview.convert('RGB')
            except (OSError, subprocess.SubprocessError):
                decoder = None
        if not decoder:
            im.thumbnail(size[::-1] if orientation in (5, 6, 7, 8) else size,
                         Image.Resampling.LANCZOS, reducing_gap=2.0)
            out = ImageOps.exif_transpose(im).convert('RGB')
    target.parent.mkdir(parents=True, exist_ok=True)
    with NamedTemporaryFile(dir=target.parent, delete=False) as temp:
        stage = Path(temp.name)
        try:
            out.save(temp, format='JPEG', quality=86 if tier == 'center' else 80)
            temp.close()
            stage.replace(target)
        finally:
            stage.unlink(missing_ok=True)
    return target


def generate(entries, tier):
    for entry in entries:
        path = Path(entry['path'])
        key = entry['key']
        try:
            url = make_preview(path, key, tier).as_uri()
            fallback = False
        except (OSError, ValueError, ImportError):
            # Qt may support formats Pillow does not. Try a size-limited decode in QML.
            url = path.as_uri()
            fallback = True
        print(json.dumps({'key': key, 'url': url, 'fallback': fallback}), flush=True)
    try:
        prune()
    except OSError:
        pass  # Failure to prune should not stop previewing an image.


if __name__ == '__main__':
    generate(json.loads(sys.argv[2]), sys.argv[1])
