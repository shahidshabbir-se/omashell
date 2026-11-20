#!/usr/bin/env python3
"""Install or remove Omashell's marked include in a local Hyprland Lua config."""

import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile

MARKER = 'omashell-standalone-display-v1\n'
BLOCK = '''
-- BEGIN OMASHELL DISPLAY (managed by install.sh)
do
  local config = os.getenv("XDG_CONFIG_HOME")
  if not config or config == "" then config = os.getenv("HOME") .. "/.config" end
  local path = config .. "/hypr/omashell-display.lua"
  local profile = io.open(path, "r")
  if profile then
    profile:close()
    dofile(path)
  end
end
-- END OMASHELL DISPLAY
'''


def write_atomic(path, contents, mode, original=None):
    temp = None
    try:
        with tempfile.NamedTemporaryFile(mode='w', encoding='utf-8', newline='', dir=path.parent,
                                         prefix='.' + path.name + '.', delete=False) as output:
            temp = Path(output.name)
            os.fchmod(output.fileno(), mode)
            output.write(contents)
        if path.is_symlink() or (original is not None and path.read_bytes() != original.encode()):
            raise ValueError(f'{path} changed while installing; left untouched')
        if original is None:
            os.link(temp, path)  # A new receipt must never replace an existing file.
        else:
            os.replace(temp, path)
    finally:
        if temp is not None:
            temp.unlink(missing_ok=True)


def configure(base, remove=False):
    if not base.is_absolute():
        return 'XDG_CONFIG_HOME must be absolute'
    hypr = base / 'hypr' / 'hyprland.lua'
    profile = hypr.with_name('omashell-display.lua')
    receipt = base / 'omashell' / 'standalone-display'
    if receipt.is_symlink() or (receipt.exists() and (
            not receipt.is_file() or receipt.read_text(encoding='utf-8') != MARKER)):
        return 'existing display setup marker is unmanaged'
    if remove and not receipt.exists():
        return None
    if hypr.resolve() != hypr or not hypr.is_file():
        return 'no regular local hyprland.lua found; leaving Hyprland configuration untouched'
    original = hypr.read_bytes().decode('utf-8')
    mode = stat.S_IMODE(hypr.stat().st_mode)
    if remove:
        if BLOCK in original:
            write_atomic(hypr, original.replace(BLOCK, '', 1), mode, original)
        elif '-- BEGIN OMASHELL DISPLAY' in original:
            return 'the display include has been edited; leaving it untouched'
        receipt.unlink(missing_ok=True)
        return None

    config = receipt.with_name('shell.json')
    if config.exists():
        display = json.loads(config.read_text(encoding='utf-8')).get('display', {})
        if isinstance(display, dict) and (display.get('profilePath') or display.get('standalonePath')):
            return 'an explicit Omashell display profile is already configured'
    if profile.is_symlink() or (profile.exists() and (not profile.is_file() or not receipt.exists())):
        return 'omashell-display.lua already exists without an installer marker; leaving it untouched'
    if BLOCK not in original and ('-- BEGIN OMASHELL DISPLAY' in original or 'omashell-display.lua' in original):
        return 'a display include is already present but not installer-managed'
    if BLOCK not in original and re.search(r'^return(?:\s|[({;]|$)', original, re.MULTILINE):
        return 'hyprland.lua contains a top-level return; leaving it untouched'

    receipt.parent.mkdir(parents=True, exist_ok=True)
    if not receipt.exists():
        write_atomic(receipt, MARKER, 0o644)
        new_receipt = True
    else:
        new_receipt = False
    try:
        if BLOCK not in original:
            write_atomic(hypr, original + BLOCK, mode, original)
    except BaseException:
        if new_receipt:
            receipt.unlink(missing_ok=True)
        raise
    return None


if __name__ == '__main__':
    path = Path(os.environ.get('XDG_CONFIG_HOME') or Path.home() / '.config')
    remove = sys.argv[1:] == ['--remove']
    try:
        reason = configure(path, remove)
    except (OSError, ValueError, AttributeError) as exc:
        reason = str(exc)
    if reason:
        print(f'install.sh: automatic Display integration skipped: {reason}', file=sys.stderr)
    elif not remove:
        print('Enabled standalone Display integration in Hyprland Lua.')
