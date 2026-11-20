#!/usr/bin/env python3
"""Small stateful simulator for the display backend; never calls a compositor."""
import json
import os
from pathlib import Path
import re
import sys

root = Path(os.environ['XDG_RUNTIME_DIR'])
path = root / 'fake-display.json'
data = json.loads(path.read_text())
monitor = data['monitor']
assert sys.argv[1:3] == ['-i', data['instance']], sys.argv
args = sys.argv[3:]
if args == ['-j', 'monitors', 'all']:
    if data.get('delay', 0) and data.get('pending'):
        data['reads'] = data.get('reads', 0) + 1
        if data['reads'] >= data['delay']:
            monitor.update(data.pop('pending'))
        path.write_text(json.dumps(data))
    print(json.dumps([monitor] + data.get('other_monitors', [])))
elif args == ['eval', 'assert(type(hl.monitor) == "function")']:
    print(data.get('probe', 'ok'))
else:
    assert args[0] == 'eval', args
    match = re.fullmatch(r'hl.monitor\(\{ output = "(eDP-1)", mode = "(\d+)x(\d+)@([.\d]+)", '
                         r'position = "auto", scale = ([.\d]+)(?:, transform = ([0-3]))? \}\)', args[1])
    assert match, args
    update = dict(width=int(match[2]), height=int(match[3]), refreshRate=float(match[4]), scale=float(match[5]),
                  transform=int(match[6] or 0))
    data.setdefault('applies', []).append(update)
    if not data.get('ignore_first') or len(data['applies']) > 1:
        if data.get('delay'):
            data['pending'], data['reads'] = update, 0
        else:
            monitor.update(update)
    path.write_text(json.dumps(data))
    print('error' if data.get('error_first') and len(data['applies']) == 1 else 'ok')
