#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
sway_pid=
cleanup() {
  if [[ -n $sway_pid ]]; then kill "$sway_pid" 2>/dev/null || true; wait "$sway_pid" 2>/dev/null || true; fi
  rm -rf -- "$tmp"
}
trap cleanup EXIT
chmod 700 "$tmp"
for dir in common config modules; do ln -s "$repo/$dir" "$tmp/$dir"; done
cp "$repo/common/tests/PanelVisibilityHarness.qml" "$tmp/shell.qml"
printf '%s\n' 'output * resolution 1280x720' 'seat * fallback true' 'xwayland disable' > "$tmp/sway.conf"
export XDG_RUNTIME_DIR="$tmp" WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 QT_QPA_PLATFORM=wayland
unset WAYLAND_DISPLAY SWAYSOCK HYPRLAND_INSTANCE_SIGNATURE || true
sway -c "$tmp/sway.conf" >"$tmp/sway.log" 2>&1 & sway_pid=$!
for _ in {1..50}; do
  socket=$(find "$tmp" -maxdepth 1 -type s -name 'wayland-*' -printf '%f\n' | head -1)
  [[ -z $socket ]] || break
  sleep .1
done
export WAYLAND_DISPLAY=${socket:-wayland-0}
if ! timeout 10 quickshell -p "$tmp/shell.qml" >"$tmp/qs.log" 2>&1 || ! grep -q 'TEST PASS' "$tmp/qs.log"; then
  cat "$tmp/qs.log"
  exit 1
fi
printf 'Panel visibility test passed.\n'
