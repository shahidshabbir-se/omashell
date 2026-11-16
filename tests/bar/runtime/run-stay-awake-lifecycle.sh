#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../.." && pwd)
tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/omashell-stay-awake-root.XXXXXX")
tmp_state=$(mktemp -d "${TMPDIR:-/tmp}/omashell-stay-awake-state.XXXXXX")

cleanup() {
  rm -rf -- "$tmp_root" "$tmp_state"
}
trap cleanup EXIT

ln -s "$repo/common" "$tmp_root/common"
ln -s "$repo/modules" "$tmp_root/modules"
ln -s "$repo/config" "$tmp_root/config"
cp "$repo/tests/bar/runtime/StayAwakeLifecycle.qml" "$tmp_root/shell.qml"

mkdir -p "$tmp_root/bin" "$tmp_state/home" "$tmp_state/config" "$tmp_state/state" "$tmp_state/runtime"
cat > "$tmp_root/bin/systemd-inhibit" <<'FAKE'
#!/bin/sh
printf 'start %s\n' "$$" >> "$OMASHELL_INHIBIT_LOG"
trap 'printf "term-start %s\n" "$$" >> "$OMASHELL_INHIBIT_LOG"; sleep 0.6; printf "term-end %s\n" "$$" >> "$OMASHELL_INHIBIT_LOG"; exit 0' TERM INT
while :; do sleep 0.2; done
FAKE
chmod +x "$tmp_root/bin/systemd-inhibit"

export HOME="$tmp_state/home"
export XDG_CONFIG_HOME="$tmp_state/config"
export XDG_STATE_HOME="$tmp_state/state"
export XDG_RUNTIME_DIR="$tmp_state/runtime"
export PATH="$tmp_root/bin:$PATH"
export OMASHELL_INHIBIT_LOG="$tmp_state/inhibit.log"
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE || true
export QT_QPA_PLATFORM=offscreen
export NO_COLOR=1
chmod 700 "$XDG_RUNTIME_DIR"

log="$tmp_state/harness.log"
set +e
timeout 8 quickshell -p "$tmp_root/shell.qml" >"$log" 2>&1
status=$?
set -e
cat "$log"
if [[ $status -ne 0 && $status -ne 1 ]]; then
  cat "$tmp_state/inhibit.log" 2>/dev/null || true
  printf '\nstay-awake harness did not exit cleanly (status %s)\n' "$status" >&2
  exit 1
fi
printf '\nInhibitor process log:\n'
cat "$tmp_state/inhibit.log" 2>/dev/null || true
if grep -Fq 'TEST PASS' "$log"; then
  printf '\nStay-awake lifecycle passed.\n'
  exit 0
fi
printf '\nStay-awake lifecycle diagnostic failed: the stop/start race is still present.\n' >&2
exit 1
