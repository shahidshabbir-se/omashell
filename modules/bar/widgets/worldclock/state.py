#!/usr/bin/env python3
"""Local world-clock preferences and first-run timezone discovery."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
from datetime import datetime, timezone
from zoneinfo import ZoneInfo, ZoneInfoNotFoundError
sys.dont_write_bytecode = True
import cities


def system_zone():
    name = os.environ.get('TZ', '').lstrip(':')
    if not name:
        try:
            link = str(Path('/etc/localtime').resolve())
            if '/zoneinfo/' in link:
                name = link.split('/zoneinfo/', 1)[1]
        except OSError:
            pass
    if not name:
        try:
            name = Path('/etc/timezone').read_text().strip()
        except OSError:
            pass
    if not name:
        try:
            name = subprocess.run(['timedatectl', 'show', '--property=Timezone', '--value'], capture_output=True, text=True, timeout=2, check=True).stdout.strip()
        except (OSError, subprocess.SubprocessError):
            pass
    try:
        ZoneInfo(name)
        return name
    except (ValueError, ZoneInfoNotFoundError):
        return 'UTC'


def valid_city(city):
    if not isinstance(city, dict):
        return False
    zone, label = city.get('zone'), city.get('label')
    if not isinstance(zone, str) or not isinstance(label, str) or not label or len(label) > 100:
        return False
    try:
        ZoneInfo(zone)
        return True
    except (ValueError, ZoneInfoNotFoundError):
        return False


def state_path():
    base = os.environ.get('XDG_STATE_HOME') or str(Path.home() / '.local/state')
    return Path(base) / 'omashell' / 'worldclock.json'


def defaults(home_zone, now=None):
    home_label = home_zone.rsplit('/', 1)[-1].replace('_', ' ')
    home = {'label': home_label, 'zone': home_zone}
    now = now or datetime.now(timezone.utc)
    preferred = [
        ['America/New_York', 'Europe/London', 'Europe/Paris', 'Asia/Tokyo'],
        ['America/Los_Angeles', 'America/Sao_Paulo', 'Asia/Dubai', 'Asia/Kolkata',
         'Asia/Singapore', 'Asia/Hong_Kong', 'Asia/Shanghai', 'Australia/Sydney'],
        ['Pacific/Honolulu', 'America/Anchorage', 'America/Vancouver', 'America/Mexico_City',
         'America/Chicago', 'America/Argentina/Buenos_Aires', 'Atlantic/Reykjavik',
         'Europe/Lisbon', 'Europe/Berlin', 'Europe/Madrid', 'Europe/Rome', 'Africa/Cairo',
         'Africa/Johannesburg', 'Europe/Istanbul', 'Europe/Moscow', 'Africa/Nairobi',
         'Asia/Karachi', 'Asia/Bangkok', 'Asia/Jakarta', 'Australia/Perth', 'Asia/Seoul',
         'Pacific/Auckland'],
    ]
    base = now.astimezone(ZoneInfo(home_zone)).utcoffset().total_seconds() / 60
    candidates = []
    for group in preferred:
        for zone in group:
            try:
                offset = now.astimezone(ZoneInfo(zone)).utcoffset().total_seconds() / 60
            except ZoneInfoNotFoundError:
                continue
            label = 'Delhi' if zone == 'Asia/Kolkata' else zone.rsplit('/', 1)[-1].replace('_', ' ')
            if zone != home_zone and label.casefold() != home_label.casefold():
                candidates.append((zone, label, (offset - base) % 1440))
    best = []
    for minimum_gap in (180, 120, 60):
        best = []
        for zone, label, delta in candidates:
            points = [0] + [item[2] for item in best]
            if all(min(abs(delta - point), 1440 - abs(delta - point)) >= minimum_gap for point in points):
                best.append((zone, label, delta))
                if len(best) == 4:
                    break
        if len(best) == 4:
            break
    return [home] + [{'label': label, 'zone': zone} for zone, label, _ in sorted(best, key=lambda item: item[2])]


def load():
    zone = system_zone()
    first_run = False
    try:
        raw = json.loads(state_path().read_text(encoding='utf-8'))
        if not isinstance(raw, dict) or not isinstance(raw.get('cities'), list):
            raise ValueError('invalid settings')
        rows = [x for x in raw['cities'] if valid_city(x)]
        here = raw.get('here') if valid_city(raw.get('here')) and raw['here']['zone'] == zone else None
    except FileNotFoundError:
        rows, here = defaults(zone), None
        first_run = True
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print('world clock settings: ' + str(exc), file=sys.stderr)
        rows, here = defaults(zone), None
    home = here or {'label': zone.rsplit('/', 1)[-1].replace('_', ' '), 'zone': zone}
    if 'lat' not in home or 'lon' not in home:
        for base in filter(None, [os.environ.get('TZDIR'), '/usr/share/zoneinfo', '/usr/share/lib/zoneinfo', '/etc/zoneinfo']):
            path = Path(base) / 'zone1970.tab'
            try:
                lines = path.read_text(encoding='utf-8').splitlines()
            except OSError:
                continue
            for line in lines:
                fields = line.split('\t')
                if len(fields) >= 3 and fields[2] == zone:
                    point = cities.coordinate(fields[1])
                    if point:
                        home['lat'], home['lon'] = point
                    break
            if 'lat' in home:
                break
    print(json.dumps({'home': home, 'here': here, 'cities': rows, 'firstRun': first_run}, ensure_ascii=False))


def save():
    raw = json.loads(sys.argv[2])
    if not isinstance(raw, dict) or not isinstance(raw.get('cities'), list) or not all(valid_city(c) for c in raw['cities']):
        raise ValueError('invalid world clock settings')
    if raw.get('here') is not None and not valid_city(raw['here']):
        raise ValueError('invalid home location')
    path = state_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temp = tempfile.mkstemp(prefix='.worldclock-', dir=path.parent)
    try:
        with os.fdopen(fd, 'w', encoding='utf-8') as file:
            json.dump(raw, file, ensure_ascii=False)
            file.write('\n')
        os.replace(temp, path)
    finally:
        if os.path.exists(temp):
            os.unlink(temp)


if __name__ == '__main__':
    try:
        save() if len(sys.argv) > 1 and sys.argv[1] == 'save' else load()
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print('world clock: ' + str(error), file=sys.stderr)
        sys.exit(1)
