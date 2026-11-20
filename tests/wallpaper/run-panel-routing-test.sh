#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
runtime=$(mktemp -d)
sway_pid=
cleanup() {
  if [[ -n $sway_pid ]]; then kill "$sway_pid" 2>/dev/null || true; wait "$sway_pid" 2>/dev/null || true; fi
  rm -rf -- "$runtime"
}
trap cleanup EXIT
chmod 700 "$runtime"
mkdir -p "$runtime/config" "$runtime/home"
cp -a "$repo"/{common,config,modules,assets} "$runtime/"
sed '/target: "omashell"/a\    function testPanel(): string { return shell.activeWidgetId }\n    function testBarClick(): void { shell.showPanelFor("wallpaper", 100) }' "$repo/shell.qml" > "$runtime/shell.qml"
printf '%s\n' 'output * resolution 1280x720' 'seat * fallback true' 'xwayland disable' > "$runtime/sway.conf"
export XDG_RUNTIME_DIR="$runtime" XDG_CONFIG_HOME="$runtime/config" HOME="$runtime/home" WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 QT_QPA_PLATFORM=wayland
unset WAYLAND_DISPLAY SWAYSOCK HYPRLAND_INSTANCE_SIGNATURE DBUS_SESSION_BUS_ADDRESS
sway -c "$runtime/sway.conf" >"$runtime/sway.log" 2>&1 & sway_pid=$!
for _ in {1..50}; do
  socket=$(find "$runtime" -maxdepth 1 -type s -name 'wayland-*' -printf '%f\n' | head -1)
  [[ -z $socket ]] || break
  sleep .1
done
export WAYLAND_DISPLAY=${socket:?failed to start headless compositor}
dbus-run-session -- bash -s -- "$runtime" "$runtime/qs.log" <<'INNER'
set -euo pipefail
qml=$1 log=$2
call() { quickshell -p "$qml" ipc call omashell "$@"; }
timeout 15 quickshell -p "$qml" >"$log" 2>&1 & qs_pid=$!
trap 'kill "$qs_pid" 2>/dev/null || true; wait "$qs_pid" 2>/dev/null || true' EXIT
for _ in {1..50}; do
  if grep -q 'Configuration Loaded' "$log"; then break; fi
  sleep .1
done
for trigger in toggleWallpaper testBarClick; do
  call "$trigger" || { cat "$log"; exit 1; }
  if [[ $(call testPanel) != wallpaper ]]; then
    printf 'FAIL: %s did not open wallpaper\n' "$trigger" >&2
    grep -E 'Cannot assign|ERROR' "$log" >&2 || true
    exit 1
  fi
  call toggleWallpaper
  [[ -z $(call testPanel) ]]
done
printf '%s\n' 'PASS: IPC opens, bar route opens, IPC toggles closed.'
INNER
