"""Display preview transactions for a single Hyprland output."""

import fcntl
import json
import math
import os
from pathlib import Path
import re
import shutil
import signal
import stat
import subprocess
import sys
import tempfile
import time
import uuid

PREVIEW_SECONDS = 15
IO_TIMEOUT = 1.5
LUA_HEADER = '-- omashell-display-profile: '
LUA_MAX = 65536
FIELDS = {"version", "connector", "width", "height", "refreshRate", "scale"}
CONNECTOR = re.compile(r"[a-zA-Z][a-zA-Z0-9]*(?:-[a-zA-Z0-9]+)*-[0-9]+", re.ASCII)
BUILT_IN = re.compile(r"(?:eDP|LVDS|DSI)-[0-9]+", re.ASCII)
SDR_FORMATS = {"XRGB8888", "XBGR8888", "ARGB8888", "ABGR8888"}
COLOR_FIELDS = ("currentFormat", "colorManagementPreset", "sdrBrightness", "sdrSaturation",
                "sdrMinLuminance", "sdrMaxLuminance")
SIGNATURE = re.compile(r"[a-zA-Z0-9_-]{1,128}")
TOKEN = re.compile(r"[a-f0-9]{32}")
MODE = re.compile(r"([0-9]+)x([0-9]+)@([0-9]+(?:\.[0-9]+)?)Hz", re.ASCII)
# Hyprland uses increments of 1/120; present a short list of common choices.
SCALE_UNITS = (120, 150, 192, 240, 360, 480)


class DisplayError(Exception):
    pass


def now():
    # Unlike CLOCK_MONOTONIC, suspend counts towards the confirmation deadline.
    return time.clock_gettime(time.CLOCK_BOOTTIME)


def valid_dimensions(width, height):
    return all(type(value) is int and 0 < value <= 16384 for value in (width, height))


def in_range(value, low, high):
    return type(value) in (int, float) and low <= value <= high


def validate(profile):
    if (not isinstance(profile, dict) or profile.keys() - {'transform', 'exactRule'} != FIELDS
            or type(profile.get('exactRule', False)) is not bool
            or type(profile.get('transform', 0)) is not int or not 0 <= profile.get('transform', 0) <= 3
            or type(profile['version']) is not int or profile['version'] != 1
            or not isinstance(profile['connector'], str) or not CONNECTOR.fullmatch(profile['connector'])
            or not valid_dimensions(profile['width'], profile['height'])
            or not in_range(profile['refreshRate'], 1, 1000)
            or not in_range(profile['scale'], 0.1, 10)):
        raise DisplayError('Invalid version 1 display profile.')
    return profile


def standalone(path):
    """A .lua path opts into the self-contained Hyprland fragment."""
    return path.suffix == '.lua'


def render_lua(profile):
    p = validate(profile)
    return f'{LUA_HEADER}{json.dumps(p, sort_keys=True, separators=(",", ":"))}\n{monitor_rule(p)}\n'


def monitor_rule(profile, explicit_transform=False):
    p = validate(profile)
    mode = f"{p['width']}x{p['height']}@{p['refreshRate']:.6f}"
    transform = f", transform = {p.get('transform', 0)}" if explicit_transform or 'transform' in p else ''
    return (f'hl.monitor({{ output = "{p["connector"]}", mode = "{mode}", '
            f'position = "auto", scale = {p["scale"]:.6f}{transform} }})')


def parse_lua(raw):
    try:
        text = raw.decode('utf-8')
        header, body = text.split('\n', 1)
        if not header.startswith(LUA_HEADER):
            raise ValueError('missing managed header')
        profile = json.loads(header[len(LUA_HEADER):])
    except (UnicodeError, ValueError) as exc:
        raise DisplayError('This .lua file is not an Omashell-managed display profile.') from exc
    profile = validate(profile)
    # Exact output: a partial regeneration or a hand edit cannot pass the check.
    if text != render_lua(profile):
        raise DisplayError('This Omashell display file was edited outside Omashell; refusing to overwrite it.')
    return profile


def read_profile(path, fallback=None):
    if not path.is_absolute() or path.resolve() != path:
        raise DisplayError('Set display.profilePath or display.standalonePath to a real, absolute path.')
    if standalone(path) and not path.exists():
        if fallback is None:
            raise DisplayError('The standalone display file does not exist; open the panel to create it.')
        if not path.parent.is_dir() or not os.access(path.parent, os.W_OK):
            raise DisplayError('The standalone display file\'s directory must exist and be writable.')
        return validate(fallback), None, 0o644
    if not path.is_file():
        raise DisplayError('Set display.profilePath or display.standalonePath to an existing regular file.')
    if not os.access(path, os.W_OK) or not os.access(path.parent, os.W_OK):
        raise DisplayError('Display profile and its directory must be writable.')
    fd = os.open(path, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK)
    with os.fdopen(fd, 'rb') as source:
        meta = os.fstat(source.fileno())
        if not stat.S_ISREG(meta.st_mode):
            raise DisplayError('Invalid display profile file.')
        raw = source.read(LUA_MAX + 1)
        if len(raw) > LUA_MAX:
            raise DisplayError('Invalid display profile file.')
    profile = parse_lua(raw) if standalone(path) else None
    if profile is None:
        try:
            profile = validate(json.loads(raw))
        except (UnicodeError, ValueError) as exc:
            raise DisplayError('Could not parse the display profile as JSON.') from exc
    # Detect a replacement even when a tool writes back byte-identical content.
    revision = (meta.st_dev, meta.st_ino, meta.st_mtime_ns, meta.st_ctime_ns, raw)
    return profile, revision, stat.S_IMODE(meta.st_mode)


def discover(hyprland):
    """Use the only connected output to bootstrap a missing standalone file."""
    monitors = hyprland.monitors()
    monitor = monitors[0] if len(monitors) == 1 else {}
    name = monitor.get('name')
    if not isinstance(name, str) or not CONNECTOR.fullmatch(name):
        raise DisplayError('Standalone display setup needs exactly one connected display.')
    _, live = hyprland.current(name)
    return live


def atomic_write(path, data, mode=0o600, before_replace=None):
    fd, temp = tempfile.mkstemp(prefix=f'.{path.name}.', dir=path.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as output:
            os.fchmod(output.fileno(), mode)
            if isinstance(data, str):
                output.write(data)
            else:
                json.dump(data, output, indent=2)
                output.write('\n')
            output.flush()
            os.fsync(output.fileno())
        if before_replace:
            before_replace()
        os.replace(temp, path)
    finally:
        Path(temp).unlink(missing_ok=True)


def save_profile(path, profile, revision, mode, permit):
    lua = standalone(path)

    def check():
        exists = path.exists()
        if (not revision and exists) or (revision and (not exists or read_profile(path)[1] != revision)):
            raise DisplayError('The profile changed during preview; your edits were not overwritten.')
        if not permit():
            raise DisplayError('Confirmation expired before the profile could be saved.')

    atomic_write(path, render_lua(profile) if lua else profile,
                 0o644 if lua else mode, check)


def profile_for(connector, width, height, refresh, scale):
    return dict(version=1, connector=connector, width=width, height=height,
                refreshRate=refresh, scale=scale)


def scale_options(width, height, current):
    units = set(SCALE_UNITS)
    units.add(round(current * 120))
    return [round(unit / 120, 6) for unit in sorted(units) if unit > 0
            and (width * 120) % unit == 0 and (height * 120) % unit == 0]


def mode_options(monitor, current):
    options = {}
    for text in monitor['availableModes']:
        match = MODE.fullmatch(text) if isinstance(text, str) else None
        if not match:
            continue
        width, height, refresh = int(match[1]), int(match[2]), float(match[3])
        if valid_dimensions(width, height) and in_range(refresh, 1, 1000):
            options.setdefault((width, height), set()).add(refresh)
    return [dict(width=w, height=h, rates=sorted(rates),
                 scales=scale_options(w, h, current['scale']))
            for (w, h), rates in sorted(options.items(), key=lambda pair: (math.prod(pair[0]), pair[0]))]


def same_settings(a, b):
    return (all(a[key] == b[key] for key in ('connector', 'width', 'height'))
            and a.get('transform', 0) == b.get('transform', 0)
            and abs(a['refreshRate'] - b['refreshRate']) < 0.006
            and abs(a['scale'] - b['scale']) < 0.0001)


class Hyprland:
    def __init__(self, executable, signature):
        if not SIGNATURE.fullmatch(signature):
            raise DisplayError('No Hyprland instance is selected.')
        self.command = [executable, '-i', signature]

    def call(self, *args):
        try:
            result = subprocess.run(self.command + list(args), capture_output=True, text=True,
                                    check=True, timeout=IO_TIMEOUT)
            return result.stdout.strip()
        except (subprocess.SubprocessError, OSError) as exc:
            raise DisplayError('Could not reach the selected Hyprland instance.') from exc

    def monitors(self):
        try:
            monitors = json.loads(self.call('-j', 'monitors', 'all'))
            if not isinstance(monitors, list) or not all(isinstance(item, dict) for item in monitors):
                raise ValueError('expected a list of outputs')
            return monitors
        except ValueError as exc:
            raise DisplayError('Hyprland did not return valid monitor information.') from exc

    def current(self, connector, strict=True, exact_rule=False):
        monitors = self.monitors()
        monitor = next((m for m in monitors if m.get('name') == connector), {})
        if strict and (len(monitors) != 1 or not monitor
                       or monitor.get('x') != 0 or monitor.get('y') != 0
                       or not isinstance(monitor.get('availableModes'), list)):
            raise DisplayError('Preview requires one connected display at the default position.')
        if (monitor.get('disabled') is not False or monitor.get('dpmsStatus') is not True
                or monitor.get('mirrorOf') != 'none' or monitor.get('transform') not in (0, 1, 2, 3)):
            raise DisplayError('The display must be on, unmirrored, and not flipped.')
        if strict and monitor.get('vrr') is not False:
            raise DisplayError('Disable variable refresh rate before previewing display settings.')
        if strict and not exact_rule and (monitor.get('currentFormat') not in SDR_FORMATS
                                          or monitor.get('colorManagementPreset') != 'srgb'):
            raise DisplayError('HDR and non-default color previews require an exact connector rule and exactRule in the profile.')
        live = profile_for(connector, monitor.get('width'), monitor.get('height'),
                           monitor.get('refreshRate'), monitor.get('scale'))
        live = validate(dict(live, transform=monitor['transform']))
        return monitor, live

    def verify_lua(self):
        if self.call('eval', 'assert(type(hl.monitor) == "function")') != 'ok':
            raise DisplayError('Display preview requires a Hyprland session using Lua configuration.')

    def apply(self, profile):
        if self.call('eval', monitor_rule(profile, explicit_transform=True)) != 'ok':
            raise DisplayError('Hyprland rejected the monitor rule.')


def choices(hyprland, profile):
    monitor, live = hyprland.current(profile['connector'], exact_rule=profile.get('exactRule', False))
    options = mode_options(monitor, live)
    if not options:
        raise DisplayError('Hyprland did not advertise any usable display modes.')
    width_mm, height_mm = monitor.get('physicalWidth'), monitor.get('physicalHeight')
    density = None
    if in_range(width_mm, 25, 2000) and in_range(height_mm, 25, 2000):
        x_ppi, y_ppi = live['width'] * 25.4 / width_mm, live['height'] * 25.4 / height_mm
        if abs(x_ppi - y_ppi) < 0.1 * max(x_ppi, y_ppi):
            density = round((x_ppi + y_ppi) / 2)
    return monitor, live, options, density


def verify(hyprland, target, end, permitted, original, strict=True, exact_rule=False):
    while now() < end and permitted():
        try:
            monitor, live = hyprland.current(target['connector'], strict, exact_rule)
            if (same_settings(live, target)
                    and monitor.get('vrr') == original.get('vrr')
                    and all(monitor.get(key) == original.get(key) for key in COLOR_FIELDS)
                    and now() < end and permitted()):
                return True
        except DisplayError:
            # Mode changes can temporarily remove the output from readback.
            pass
        time.sleep(0.08)
    return False


def runtime():
    directory = Path(os.environ['XDG_RUNTIME_DIR']) / 'omashell-display'
    if not directory.is_absolute():
        raise DisplayError('An absolute XDG_RUNTIME_DIR is required.')
    directory.mkdir(mode=0o700, exist_ok=True)
    info = directory.lstat()
    if not stat.S_ISDIR(info.st_mode) or info.st_uid != os.getuid() or info.st_mode & 0o077:
        raise DisplayError('Display runtime directory is not private.')
    return directory


def transaction(token):
    if not TOKEN.fullmatch(token):
        raise DisplayError('Invalid display transaction.')
    return runtime() / token


def status(directory, state, message='', **fields):
    atomic_write(directory / 'status.json', dict(state=state, message=message, **fields))


def read_status(directory):
    data = json.loads((directory / 'status.json').read_text())
    if data['state'] in ('starting', 'applying', 'preview') and now() > data['expires']:
        return dict(state='error', message='The display watchdog did not finish. Check the display and try again.')
    if data['state'] == 'preview':
        data['seconds'] = max(0, math.ceil(data['deadline'] - now()))
    return data


def request(directory, action):
    current = read_status(directory)
    if current['state'] not in ('starting', 'applying', 'preview'):
        return
    if action == 'keep' and (current['state'] != 'preview' or not current['seconds']):
        return
    try:
        # Publish exactly one decision without exposing a partially written request.
        (directory / 'decision').symlink_to(action)
    except FileExistsError:
        pass


def decision(directory):
    try:
        return (directory / 'decision').readlink().name
    except FileNotFoundError:
        return ''


def worker(directory, hyprland, profile_path, target, preview_seconds=PREVIEW_SECONDS):
    baseline = None
    changed = False
    state, message = 'error', 'Preview was interrupted.'
    stop = False

    def stop_worker(_signum, _frame):
        nonlocal stop
        stop = True

    signal.signal(signal.SIGTERM, stop_worker)
    lock_path = directory.parent / ('instance-' + hyprland.command[-1] + '.lock')
    with lock_path.open('a') as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            status(directory, 'error', 'A display preview is already running for this session.')
            return
        try:
            status(directory, 'applying', expires=now() + 30)
            profile, revision, mode = read_profile(profile_path, target)
            if target['connector'] != profile['connector']:
                raise DisplayError('The configured display changed. Reopen the panel and try again.')
            original, baseline, options, _density = choices(hyprland, profile)
            exact_rule = profile.get('exactRule', False)
            if not any((option['width'], option['height']) == (target['width'], target['height'])
                       and target['refreshRate'] in option['rates'] and target['scale'] in option['scales']
                       for option in options):
                raise DisplayError('Select an advertised resolution and refresh rate, and a compatible scale.')
            restore_rate = next((rate for option in options
                                 if (option['width'], option['height']) == (baseline['width'], baseline['height'])
                                 for rate in option['rates'] if abs(rate - baseline['refreshRate']) < 0.006), None)
            if restore_rate is None:
                raise DisplayError('Cannot safely restore the current mode: it is not advertised by this display.')
            restore_scale = next((scale for scale in scale_options(baseline['width'], baseline['height'], baseline['scale'])
                                  if abs(scale - baseline['scale']) < 0.0001), None)
            if restore_scale is None:
                raise DisplayError('Cannot safely restore the current display scale.')
            baseline = dict(baseline, refreshRate=restore_rate, scale=restore_scale)
            hyprland.verify_lua()
            if stop or decision(directory) == 'cancel':
                state, message = 'reverted', ''
                return

            deadline = now() + preview_seconds

            def permitted():
                return not stop and now() < deadline

            def still_previewing():
                return permitted() and decision(directory) != 'cancel'

            # Arm rollback before sending the mutating request: even a timed-out
            # hyprctl client may already have handed the rule to the compositor.
            # Lua updates an existing rule with the same output selector. Only
            # mutate geometry so that a connector-specific rule keeps its color options.
            changed = True
            hyprland.apply(target)
            if not verify(hyprland, target, min(deadline, now() + 4), still_previewing, original,
                          exact_rule=exact_rule):
                if decision(directory) == 'cancel':
                    state, message = 'reverted', ''
                else:
                    raise DisplayError('Could not verify the requested mode with the original color settings.')
            else:
                # Give the user the full window after the mode has been verified.
                deadline = now() + preview_seconds
                status(directory, 'preview', deadline=deadline, expires=deadline + 12)
                while permitted():
                    action = decision(directory)
                    if action == 'cancel':
                        state, message = 'reverted', ''
                        break
                    if action == 'keep':
                        if not verify(hyprland, target, min(deadline, now() + 1), permitted, original,
                                      exact_rule=exact_rule):
                            raise DisplayError('The requested mode is no longer active or confirmation expired.')
                        saved = {**target, 'exactRule': exact_rule} if 'exactRule' in profile else target
                        save_profile(profile_path, saved, revision, mode, permitted)
                        changed = False
                        state, message = 'kept', ''
                        break
                    time.sleep(0.08)
                else:
                    state, message = 'reverted', ''
        except DisplayError as exc:
            state, message = 'error', str(exc)
        except (OSError, ValueError) as exc:
            state, message = 'error', f'Display preview could not finish: {exc}'
        finally:
            if changed:
                restored = False
                for _attempt in range(2):
                    try:
                        hyprland.apply(baseline)
                        if verify(hyprland, baseline, now() + 2, lambda: True, original, strict=False):
                            restored = True
                            break
                    except DisplayError:
                        pass
                if not restored:
                    state, message = 'error', 'Could not verify rollback. Reload your Hyprland configuration to restore its rule.'
            status(directory, state, message)


def start(profile_path, target, executable, instance):
    launcher = shutil.which('systemd-run')
    if not launcher:
        raise DisplayError('Cannot preview safely without systemd-run and a systemd user manager.')
    directory_root = runtime()
    for entry in directory_root.iterdir():
        if TOKEN.fullmatch(entry.name) and entry.is_dir() and time.time() - entry.stat().st_mtime > 3600:
            shutil.rmtree(entry, ignore_errors=True)
    token = uuid.uuid4().hex
    directory = transaction(token)
    directory.mkdir(mode=0o700)
    status(directory, 'starting', expires=now() + 35)
    try:
        subprocess.run([
            launcher, '--user', '--quiet', '--collect', '--service-type=exec',
            '--property=RuntimeMaxSec=40s', '--property=TimeoutStopSec=12s',
            '--unit=omashell-display-' + token,
            '--setenv=XDG_RUNTIME_DIR=' + os.environ['XDG_RUNTIME_DIR'],
            '--', sys.executable, str(Path(__file__).resolve()), 'worker', token,
            str(profile_path), json.dumps(target), executable, instance,
        ], capture_output=True, check=True, timeout=5)
    except (subprocess.SubprocessError, OSError) as exc:
        # Start may have reached the user manager even if its client timed out.
        # Publish cancellation if a worker races the error; its own timer still applies.
        request(directory, 'cancel')
        raise DisplayError('Could not start the independent display watchdog in the systemd user manager.') from exc
    return dict(token=token)


def main(args):
    command, *params = args
    if command == 'text-size':
        size = int(params[0])
        if size not in (9, 10, 11, 12, 14, 16, 20):
            raise DisplayError('Invalid Omashell text size.')
        base = Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state')
        if not base.is_absolute():
            raise DisplayError('XDG_STATE_HOME must be absolute.')
        path = base / 'omashell' / 'text-size'
        path.parent.mkdir(mode=0o700, parents=True, exist_ok=True)
        atomic_write(path, f'{size}\n')
        return dict(size=size)
    if command in ('inspect', 'start'):
        path = Path(params[0])
        instance = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE', '')
        executable = shutil.which('hyprctl')
        if not executable:
            raise DisplayError('hyprctl is not installed.')
        executable = str(Path(executable).absolute())
        hyprland = Hyprland(executable, instance)
        if command == 'inspect':
            hyprland.verify_lua()
            fallback = discover(hyprland) if standalone(path) and not path.exists() else None
            profile, _revision, _mode = read_profile(path, fallback)
            monitor, live, options, density = choices(hyprland, profile)
            connector = live['connector']
            model = monitor.get('model')
            name = ('Built-in Display' if BUILT_IN.fullmatch(connector) else
                    f'{model.strip()} ({connector})' if isinstance(model, str) and model.strip() else connector)
            return dict(live=live, saved=profile, options=options, density=density,
                        name=name,
                        standalone=standalone(path), initialized=fallback is None)
        target = validate(json.loads(params[1]))
        read_profile(path, target)
        return start(path, target, executable, instance)
    directory = transaction(params[0])
    if command == 'status':
        return read_status(directory)
    if command in ('keep', 'cancel'):
        request(directory, command)
        return {}
    if command == 'worker':
        worker(directory, Hyprland(params[3], params[4]), Path(params[1]), validate(json.loads(params[2])))
        return {}
    raise DisplayError('Unknown display operation.')


if __name__ == '__main__':
    try:
        print(json.dumps(main(sys.argv[1:])))
    except (DisplayError, OSError, RuntimeError, ValueError, KeyError, IndexError) as exc:
        print(json.dumps(dict(error=str(exc))))
        sys.exit(1)
