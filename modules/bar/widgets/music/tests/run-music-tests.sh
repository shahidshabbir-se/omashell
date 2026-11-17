#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/root" "$tmp/runtime"
chmod 700 "$tmp/runtime"
for dir in modules config common; do ln -s "$repo/$dir" "$tmp/root/$dir"; done
cp "$repo/modules/bar/widgets/music/tests/MusicHarness.qml" "$tmp/root/shell.qml"
export QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$tmp/runtime"
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE || true
if ! timeout 10 "${QUICKSHELL:-quickshell}" -p "$tmp/root/shell.qml" >"$tmp/log" 2>&1 || ! grep -q 'TEST PASS' "$tmp/log"; then
  cat "$tmp/log"
  exit 1
fi
if grep -Eq 'TypeError|ReferenceError|Failed to load configuration' "$tmp/log"; then
  cat "$tmp/log"
  exit 1
fi
printf 'Music component smoke test passed.\n'
