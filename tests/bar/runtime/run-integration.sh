#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/omashell-bar-integration-root.XXXXXX")
tmp_state=$(mktemp -d "${TMPDIR:-/tmp}/omashell-bar-integration-state.XXXXXX")

cleanup() {
  rm -rf -- "$tmp_root" "$tmp_state"
}
trap cleanup EXIT

# A disposable qs import root: qs.common, qs.config and qs.modules point at
# this checkout, while shell.qml is the harness copied into the temp root.
ln -s "$repo/common" "$tmp_root/common"
ln -s "$repo/modules" "$tmp_root/modules"
ln -s "$repo/config" "$tmp_root/config"
cp "$repo/tests/bar/runtime/BarSectionIntegration.qml" "$tmp_root/shell.qml"

export HOME="$tmp_state/home"
export XDG_CONFIG_HOME="$tmp_state/config"
export XDG_STATE_HOME="$tmp_state/state"
export XDG_RUNTIME_DIR="$tmp_state/runtime"
mkdir -p "$HOME" "$XDG_CONFIG_HOME/omashell" "$XDG_STATE_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Do not contact or mutate the live desktop shell. PanelWindow is not available
# under the offscreen backend, so this harness covers BarSection and widget
# wiring rather than Bar/PanelShell surfaces.
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE || true
export QT_QPA_PLATFORM=offscreen
export NO_COLOR=1

cat > "$XDG_CONFIG_HOME/omashell/shell.json" <<'JSON'
{
  "version": 1,
  "bar": {
    "position": "top",
    "left": [],
    "centerBegin": [
      { "id": "indicators", "alwaysShow": true, "items": ["Dnd", "StayAwake"] }
    ],
    "center": [
      { "id": "clock", "format": "HH:mm:ss" }
    ],
    "centerEnd": [],
    "right": []
  }
}
JSON

log="$tmp_state/integration.log"
if ! timeout 20 quickshell -p "$tmp_root/shell.qml" >"$log" 2>&1; then
  cat "$log"
  printf '\nbar integration harness failed to run\n' >&2
  exit 1
fi
if ! grep -Fq 'TEST PASS' "$log"; then
  cat "$log"
  printf '\nmissing TEST PASS in bar integration harness\n' >&2
  exit 1
fi
grep -E 'CHECK|TEST|RESULT' "$log" || true
printf 'Bar integration runtime tests passed.\n'
