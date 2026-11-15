#!/usr/bin/env python3
"""Emit locations supplied by the system IANA timezone database."""
import json
import os
from pathlib import Path
import re
from zoneinfo import available_timezones


def coordinate(value):
    match = re.fullmatch(r'([+-])(\d{2})(\d{2})(\d{2})?([+-])(\d{3})(\d{2})(\d{2})?', value)
    if not match:
        return None
    s1, a, b, c, s2, d, e, f = match.groups()
    lat = (int(a) + int(b) / 60 + int(c or 0) / 3600) * (-1 if s1 == '-' else 1)
    lon = (int(d) + int(e) / 60 + int(f or 0) / 3600) * (-1 if s2 == '-' else 1)
    return lat, lon


def main():
    roots = [os.environ.get('TZDIR', ''), '/usr/share/zoneinfo', '/usr/share/lib/zoneinfo', '/etc/zoneinfo']
    locations = {}
    root_path = None
    for root in filter(None, roots):
        for name in ('zone1970.tab', 'zone.tab'):
            path = Path(root) / name
            if not path.is_file():
                continue
            root_path = Path(root)
            for line in path.read_text(encoding='utf-8').splitlines():
                if not line or line.startswith('#'):
                    continue
                fields = line.split('\t')
                if len(fields) >= 3:
                    point = coordinate(fields[1])
                    if point:
                        locations[fields[2]] = point
        if root_path:
            break
    result = []
    for zone in sorted(available_timezones() | locations.keys()):
        if '/' not in zone:
            continue
        item = {'label': zone.rsplit('/', 1)[-1].replace('_', ' '), 'zone': zone}
        point = locations.get(zone)
        if point is None and root_path:
            try:
                resolved = (root_path / zone).resolve().relative_to(root_path.resolve()).as_posix()
                point = locations.get(resolved)
            except (OSError, ValueError):
                pass
        if point is not None:
            item['lat'], item['lon'] = point
        result.append(item)
    print(json.dumps(result, ensure_ascii=False))


if __name__ == '__main__':
    main()
