"""Read or adjust an unambiguous kernel backlight, without elevated privileges."""

import json
import re
import subprocess
import sys


class BacklightError(Exception):
    pass


def brightnessctl(*arguments):
    try:
        return subprocess.run(
            ['brightnessctl', '--machine-readable', '--class=backlight', *arguments],
            capture_output=True, check=True, text=True, timeout=1.5,
        ).stdout.strip()
    except (OSError, subprocess.SubprocessError) as exc:
        raise BacklightError('Could not access the laptop backlight with brightnessctl.') from exc


def parse_device(output):
    lines = output.splitlines()
    if len(lines) != 1:
        raise BacklightError('No unambiguous laptop backlight was found.')
    fields = lines[0].split(',')
    if (len(fields) != 5 or fields[1] != 'backlight' or not re.fullmatch(r'[a-zA-Z0-9_.:-]+', fields[0])
            or not fields[2].isdigit() or not fields[4].isdigit()):
        raise BacklightError('Could not read the laptop backlight.')
    device, _, current, _, maximum = fields
    current, maximum = int(current), int(maximum)
    if not 0 <= current <= maximum or not maximum:
        raise BacklightError('Could not read the laptop backlight range.')
    return device, round(100 * current / maximum)


def brightness(percent=None):
    device, value = parse_device(brightnessctl('--list'))
    if percent is None:
        return value
    if not 1 <= percent <= 100:
        raise BacklightError('Select brightness between 1% and 100%.')
    brightnessctl(f'--device={device}', '--min-value=1', 'set', f'{percent}%')
    _device, value = parse_device(brightnessctl(f'--device={device}', 'info'))
    return value


if __name__ == '__main__':
    try:
        value = brightness(int(sys.argv[1]) if len(sys.argv) == 2 else None)
        print(json.dumps(dict(value=value)))
    except (BacklightError, ValueError) as exc:
        print(json.dumps(dict(error=str(exc))))
        sys.exit(1)
