#!/usr/bin/env python3
"""Keep Omasnap's optional Omarchy notifier silent when it is not installed."""

from pathlib import Path
import sys

if len(sys.argv) != 2:
    raise SystemExit("usage: patch-omasnap-optional-notifier.py CAPTURE_CPP")

source = Path(sys.argv[1])
text = source.read_text()
needle = '''  const QString program = QStringLiteral("omarchy-notification-send");
  const bool toast = notifySavedCaptures() && !imagePath.isEmpty();
'''
replacement = '''  const QString program = QStringLiteral("omarchy-notification-send");
  // This is an optional Omarchy integration. Non-Omarchy installs should not
  // emit a process-start warning merely because the helper is absent.
  if (!launcher && QStandardPaths::findExecutable(program).isEmpty())
    return;
  const bool toast = notifySavedCaptures() && !imagePath.isEmpty();
'''

if replacement in text:
    raise SystemExit(0)
if text.count(needle) != 1:
    raise SystemExit(f"expected one notifier call site in {source}; source may have changed")
source.write_text(text.replace(needle, replacement, 1))
