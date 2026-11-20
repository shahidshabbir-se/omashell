#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../../.." && pwd)
tmp=$(mktemp -d)
sway_pid=; qs_pid=; keyboard_pid=
cleanup() {
  [[ -z $keyboard_pid ]] || { kill "$keyboard_pid" 2>/dev/null || true; wait "$keyboard_pid" 2>/dev/null || true; }
  [[ -z $qs_pid ]] || { kill "$qs_pid" 2>/dev/null || true; wait "$qs_pid" 2>/dev/null || true; }
  [[ -z $sway_pid ]] || { kill "$sway_pid" 2>/dev/null || true; wait "$sway_pid" 2>/dev/null || true; }
  rm -rf -- "$tmp"
}
trap cleanup EXIT
chmod 700 "$tmp"
protocol="$(pkg-config --variable=pkgdatadir wlr-protocols)/unstable/wlr-virtual-pointer-unstable-v1.xml"
wayland-scanner client-header "$protocol" "$tmp/virtual-pointer.h"
wayland-scanner private-code "$protocol" "$tmp/virtual-pointer.c"
cc -I"$tmp" "$repo/modules/bar/widgets/music/tests/virtual-click.c" "$tmp/virtual-pointer.c" $(pkg-config --cflags --libs wayland-client) -o "$tmp/virtual-click"
for dir in common config modules; do ln -s "$repo/$dir" "$tmp/$dir"; done
cp "$repo/modules/bar/widgets/music/tests/MusicDismissHarness.qml" "$tmp/shell.qml"
printf '%s\n' 'output * resolution 1280x720' 'seat * fallback true' 'xwayland disable' > "$tmp/sway.conf"
export XDG_RUNTIME_DIR="$tmp" WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 QT_QPA_PLATFORM=wayland
unset WAYLAND_DISPLAY SWAYSOCK HYPRLAND_INSTANCE_SIGNATURE || true
sway -c "$tmp/sway.conf" >"$tmp/sway.log" 2>&1 & sway_pid=$!
for _ in {1..60}; do
  wayland=$(find "$tmp" -maxdepth 1 -type s -name 'wayland-*' -printf '%f\n' | head -1)
  sway_socket=$(find "$tmp" -maxdepth 1 -type s -name 'sway-ipc.*.sock' -print | head -1)
  [[ -z $wayland || -z $sway_socket ]] || break
  sleep .1
done
if [[ -z $wayland || -z $sway_socket ]]; then
  cat "$tmp/sway.log" >&2
  exit 1
fi
export WAYLAND_DISPLAY=$wayland SWAYSOCK=$sway_socket
# Keep a virtual keyboard connected when the panel maps, as on a real desktop.
wtype -s 6500 & keyboard_pid=$!
timeout 10 quickshell -p "$tmp/shell.qml" >"$tmp/qs.log" 2>&1 & qs_pid=$!
wait_for_panel() {
  local phase=$1
  for _ in {1..40}; do
    if grep -q "TEST READY $phase" "$tmp/qs.log"; then return 0; fi
    if ! kill -0 "$qs_pid" 2>/dev/null; then break; fi
    sleep .1
  done
  cat "$tmp/qs.log" >&2
  return 1
}
wait_for_panel click
sleep .4
"$tmp/virtual-click"
wait_for_panel escape
sleep .4
wtype -k Escape
if ! wait "$qs_pid"; then qs_pid=; cat "$tmp/qs.log" >&2; exit 1; fi
qs_pid=
grep -E 'TEST (READY|FAIL|PASS)' "$tmp/qs.log"
grep -q 'TEST PASS' "$tmp/qs.log"
