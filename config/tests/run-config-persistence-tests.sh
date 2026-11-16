#!/usr/bin/env bash
set -euo pipefail

repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp_root=$(mktemp -d "${TMPDIR:-/tmp}/omashell-config-tests-root.XXXXXX")
tmp_state=$(mktemp -d "${TMPDIR:-/tmp}/omashell-config-tests-state.XXXXXX")

cleanup() {
  rm -rf -- "$tmp_root" "$tmp_state"
}
trap cleanup EXIT

# Build a disposable Quickshell config root whose qs.config points at this
# checkout. The harness is copied in, so nothing is written to the repository.
ln -s "$repo/config" "$tmp_root/config"
ln -s "$repo/modules" "$tmp_root/modules"
cp "$repo/config/tests/ConfigPersistenceHarness.qml" "$tmp_root/shell.qml"

export HOME="$tmp_state/home"
export XDG_CONFIG_HOME="$tmp_state/config"
export XDG_RUNTIME_DIR="$tmp_state/runtime"
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_RUNTIME_DIR"
chmod 700 "$XDG_RUNTIME_DIR"

# Do not contact or mutate the user's live desktop shell.
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE || true
export QT_QPA_PLATFORM=offscreen
export NO_COLOR=1

config_file="$XDG_CONFIG_HOME/omashell/shell.json"

write_config() {
  mkdir -p "$(dirname "$config_file")"
  cat > "$config_file"
}

remove_config() {
  unlink -- "$config_file" 2>/dev/null || true
}

run_phase() {
  local phase=$1 position=${2:-} format=${3:-}
  local log="$tmp_state/$phase.log"
  if ! env \
    OMASHELL_CONFIG_TEST_PHASE="$phase" \
    OMASHELL_CONFIG_TEST_EXPECT_POSITION="$position" \
    OMASHELL_CONFIG_TEST_EXPECT_FORMAT="$format" \
    timeout 15 quickshell -p "$tmp_root/shell.qml" >"$log" 2>&1
  then
    cat "$log"
    printf '\nfailed phase: %s\n' "$phase" >&2
    exit 1
  fi
  if ! grep -Fq 'TEST PASS' "$log"; then
    cat "$log"
    printf '\nmissing TEST PASS for phase: %s\n' "$phase" >&2
    exit 1
  fi
  printf 'ok: %s\n' "$phase"
}

# No user file: exercise the bundled config/shell.json and Config.qml defaults.
run_phase bundled-defaults

write_config <<'JSON'
{
  "version": 1,
  "bar": {
    "position": "bottom",
    "left": ["logo", "workspaces"],
    "center": [
      { "id": "clock", "format": 4 }
    ],
    "right": ["audio"]
  }
}
JSON
run_phase startup-race
run_phase restart-verify bottom 5

remove_config
run_phase startup-no-user
run_phase restart-verify bottom 6

write_config <<'JSON'
{
  "version": 1,
  "bar": {
    "position": "bottom",
    "left": ["logo"],
    "centerBegin": [],
    "center": [
      { "id": "clock", "format": 4 }
    ],
    "centerEnd": [],
    "right": ["audio"]
  }
}
JSON
run_phase external-edit
run_phase restart-verify right 8

run_phase invalid-external
run_phase restart-verify left 11

run_phase external-delete
run_phase restart-verify top 12

printf 'Config persistence tests passed.\n'
