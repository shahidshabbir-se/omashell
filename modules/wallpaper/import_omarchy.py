"""Install only image blobs from Omarchy's upstream wallpaper directories."""
import argparse
from collections import defaultdict
import hashlib
import json
from pathlib import Path, PurePosixPath
import sys
from tempfile import TemporaryDirectory
from urllib.error import URLError
from urllib.parse import quote
from urllib.request import Request, urlopen

from library import BLOB, FORMATS, THEME, data_dir


TREE = 'https://api.github.com/repos/omacom/omarchy/git/trees/HEAD?recursive=1'
RAW = 'https://raw.githubusercontent.com/omacom/omarchy'
MAX_IMAGE = 64 * 1024 * 1024


def request(url):
    return urlopen(Request(url, headers={'User-Agent': 'Omashell-wallpapers'}), timeout=30)


def catalog(tree):
    revision = tree['sha']
    if tree.get('truncated') is not False or not BLOB.fullmatch(revision):
        raise ValueError('Upstream wallpaper catalog is incomplete.')
    themes = defaultdict(list)
    for entry in tree['tree']:
        parts = entry['path'].split('/')
        if len(parts) != 4 or parts[0] != 'themes' or parts[2] != 'backgrounds':
            continue
        _, theme, _, name = parts
        if (THEME.fullmatch(theme) and name and not name.startswith('.')
                and not any(ord(char) < 32 for char in name)
                and PurePosixPath(name).suffix.lower() in FORMATS
                and entry.get('type') == 'blob' and entry.get('mode') in ('100644', '100755')
                and BLOB.fullmatch(entry.get('sha', ''))):
            themes[theme].append(entry)
    return revision, dict(sorted(themes.items()))


def choose(themes, selection):
    if selection == 'all':
        return list(themes)
    names = list(themes)
    chosen = []
    for item in selection.replace(',', ' ').split():
        if item.isascii() and item.isdecimal() and 1 <= int(item) <= len(names):
            item = names[int(item) - 1]
        if item not in themes:
            raise ValueError(f'Unknown Omarchy wallpaper theme: {item}')
        if item not in chosen:
            chosen.append(item)
    return chosen


def download(revision, entries, destination):
    completed = 0
    seen = set()
    for entry in entries:
        blob = entry['sha']
        if blob in seen:
            continue
        seen.add(blob)
        size = entry.get('size')
        if not isinstance(size, int) or not 0 < size <= MAX_IMAGE:
            raise ValueError(f'Image exceeds the download limit: {entry["path"]}')
        folder = destination / blob
        target = folder / PurePosixPath(entry['path']).name
        if folder.is_dir() and any(p.is_file() for p in folder.iterdir()):
            continue
        destination.mkdir(parents=True, exist_ok=True)
        print(f'Downloading {entry["path"]}', flush=True)
        url = f'{RAW}/{revision}/{quote(entry["path"])}'
        with TemporaryDirectory(dir=destination) as stage:
            file = Path(stage) / target.name
            digest = hashlib.sha1(f'blob {size}\0'.encode(), usedforsecurity=False)
            total = 0
            with request(url) as response, file.open('wb') as output:
                while chunk := response.read(128 * 1024):
                    total += len(chunk)
                    if total > size:
                        raise ValueError(f'Download does not match upstream: {target.name}')
                    digest.update(chunk)
                    output.write(chunk)
            if total != size or digest.hexdigest() != blob:
                raise ValueError(f'Download does not match upstream: {target.name}')
            folder.mkdir(exist_ok=True)
            file.replace(target)
        completed += 1
    return completed


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('selection', nargs='?', help='all, or a comma-separated list of theme names')
    args = parser.parse_args()
    if args.selection is None:
        if not (sys.stdin.isatty() and sys.stdout.isatty()):
            return
        if input('Download Omarchy wallpapers? [y/N] ').strip().lower() not in ('y', 'yes'):
            return
    with request(TREE) as response:
        revision, themes = catalog(json.load(response))
    if not themes:
        raise ValueError('No wallpapers found upstream.')
    if args.selection is None:
        for number, (name, entries) in enumerate(themes.items(), 1):
            print(f'  {number:2}. {name} ({len(entries)} images)')
        selection = input('Enter theme numbers/names separated by commas, "all", or Enter to skip: ').strip()
    else:
        selection = args.selection
    selected = choose(themes, selection)
    if selected:
        count = download(revision, (entry for theme in selected for entry in themes[theme]), data_dir() / 'omarchy')
        print(f'Added {count} new Omarchy wallpapers; your active wallpaper was not changed.')


if __name__ == '__main__':
    try:
        main()
    except EOFError:
        pass  # Closed prompt: proceed without downloading.
    except (URLError, OSError, ValueError, KeyError) as error:
        sys.exit(f'Omarchy wallpapers: {error}')
