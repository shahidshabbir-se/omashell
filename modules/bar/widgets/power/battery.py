#!/usr/bin/env python3
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def command(*args):
    try:
        return subprocess.run(args, capture_output=True, text=True, timeout=4, check=True).stdout
    except (OSError, subprocess.SubprocessError):
        return ''


def parse_upower(text):
    values = {}
    for line in text.splitlines():
        if ':' in line:
            key, value = line.strip().split(':', 1)
            values[key] = value.strip()
    return values


def number(value):
    match = re.match(r'^\s*(-?\d+(?:\.\d+)?)', str(value or ''))
    return float(match.group(1)) if match else None


def sysnumber(path):
    try:
        return number(path.read_text().strip())
    except OSError:
        return None


def duration(minutes):
    if not minutes or minutes < 1:
        return ''
    hours, mins = divmod(round(minutes), 60)
    if hours and mins:
        return f'{hours}h {mins}m'
    return f'{hours}h' if hours else f'{mins}m'


def battery_reading(values, supply_root=Path('/sys/class/power_supply')):
    native = values.get('native-path', '')
    path = supply_root / native if native and Path(native).name == native else None
    def sysval(name):
        return sysnumber(path / name) if path else None
    energy = number(values.get('energy'))
    full = number(values.get('energy-full'))
    rate = number(values.get('energy-rate'))
    watts = sysval('power_now')
    current, voltage = sysval('current_now'), sysval('voltage_now')
    if watts is not None:
        rate = watts / 1000000
    elif current is not None and voltage is not None:
        rate = current * voltage / 1000000000000
    rate = abs(rate) if rate is not None else None
    start = sysval('charge_control_start_threshold')
    end = sysval('charge_control_end_threshold')
    if start is None:
        start = number(values.get('charge-start-threshold'))
    if end is None:
        end = number(values.get('charge-end-threshold'))
    cycles = number(values.get('charge-cycles'))
    if cycles is None:
        cycles = sysval('cycle_count')
    state = values.get('state', '')
    minutes = None
    if energy is not None and full is not None and rate is not None and rate > 0.2:
        remaining = full * (end if end is not None else 100) / 100 - energy if state == 'charging' else energy
        minutes = remaining / rate * 60
    else:
        for key in ('time to empty', 'time to full'):
            value = values.get(key, '')
            n = number(value)
            if n is not None:
                minutes = n if 'minute' in value else n * 60
                break
    threshold = ''
    if end is not None:
        threshold = f'{int(start)}-{int(end)}%' if start is not None and start != end else f'{int(end)}%'
    return {
        'size': f'{int(full)}Wh' if full is not None else '—',
        'cycles': str(int(cycles)) if cycles is not None else '—',
        'rate': (f'{rate:.1f}'.removesuffix('.0') + 'W') if rate is not None else '—',
        'threshold': threshold,
        'chargeEnd': end,
        'time': duration(minutes),
    }


def profiles(text):
    found = []
    active = ''
    for line in text.splitlines():
        match = re.fullmatch(r'\s*(\*\s*)?([a-zA-Z0-9-]+):\s*', line)
        if match:
            found.append(match.group(2))
            if match.group(1):
                active = match.group(2)
    return list(reversed(found)), active


def read_status():
    result = {'battery': {}, 'profiles': [], 'activeProfile': ''}
    for device in command('upower', '-e').splitlines():
        if '/battery_' not in device:
            continue
        values = parse_upower(command('upower', '-i', device))
        if values.get('power supply') == 'yes':
            result['battery'] = battery_reading(values)
            break
    result['profiles'], result['activeProfile'] = profiles(command('powerprofilesctl', 'list'))
    return result


def settings_path():
    return Path(os.environ.get('XDG_STATE_HOME') or Path.home() / '.local/state') / 'omashell' / 'power.json'


def read_settings():
    try:
        data = json.loads(settings_path().read_text())
        if not isinstance(data, dict):
            return {}
        return data
    except (OSError, ValueError):
        return {}


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else 'status'
    if action == 'status':
        print(json.dumps(read_status()))
    elif action == 'get':
        data = read_settings()
        print(json.dumps({'showPercentage': data.get('showPercentage') is True,
                          'profiles': data.get('profiles') if isinstance(data.get('profiles'), dict) else {}}))
    elif action == 'set' and len(sys.argv) == 3:
        data = json.loads(sys.argv[2])
        if not isinstance(data, dict) or not isinstance(data.get('showPercentage'), bool):
            raise SystemExit(2)
        preferred = data.get('profiles', {})
        if not isinstance(preferred, dict) or any(k not in ('ac', 'battery') or v not in ('power-saver', 'balanced', 'performance') for k, v in preferred.items()):
            raise SystemExit(2)
        path = settings_path()
        path.parent.mkdir(parents=True, exist_ok=True)
        temporary = path.with_suffix('.tmp')
        temporary.write_text(json.dumps({'showPercentage': data['showPercentage'], 'profiles': preferred}))
        temporary.replace(path)
    else:
        raise SystemExit(2)


if __name__ == '__main__':
    main()
