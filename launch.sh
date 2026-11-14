#!/usr/bin/env bash
# Launch omashell the same way for a human and for an agent, so nobody debugs a
# difference that is only environment.
#
#   ./launch.sh              run the shell from this repo
#   ./launch.sh --restart    replace a running instance of this repo
#   ./launch.sh --echo       print what would run, then exit
#
# Everything the shell needs is resolved here:
#   * HYPRLAND_INSTANCE_SIGNATURE, from `hyprctl -j instances` piped through jq.
#     Writing it as `hyprctl -j instances J -r ...` (a typo for `| jq -r`) puts
#     raw JSON in the variable, which silently gives the shell the wrong (or no)
#     Hyprland instance, and surfaces then map at a different scale.
#   * the qs binary: PATH first, then the nix store, because `qs` is not always
#     on an agent's PATH.
#
# Quickshell imports the repo root as `qs`, so -p must be the absolute repo path.

set -euo pipefail

here="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
restart=0
echo_only=0

for arg in "$@"; do
  case "$arg" in
    --restart) restart=1 ;;
    --echo) echo_only=1 ;;
    --help | -h)
      sed -n '2,18p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      printf 'unknown argument: %s\n' "$arg" >&2
      exit 2
      ;;
  esac
done

# --- qs binary ---------------------------------------------------------------
qs_bin="$(command -v qs 2>/dev/null || true)"
if [ -z "$qs_bin" ]; then
  qs_bin="$(find /nix/store -maxdepth 4 -path '*/bin/qs' -type f 2>/dev/null \
    | sed 's|/bin/qs$||' | sort -V | tail -n 1)/bin/qs"
fi
if [ -z "$qs_bin" ]; then
  printf 'launch.sh: no qs binary found in PATH or /nix/store\n' >&2
  exit 1
fi

# --- hyprland instance -------------------------------------------------------
if ! command -v hyprctl >/dev/null 2>&1; then
  printf 'launch.sh: hyprctl not found; is Hyprland running?\n' >&2
  exit 1
fi

signature=""
if command -v jq >/dev/null 2>&1; then
  signature="$(hyprctl -j instances | jq -r '.[0].instance // empty')"
fi
if [ -z "$signature" ]; then
  printf 'launch.sh: could not read a Hyprland instance signature (jq missing?)\n' >&2
  exit 1
fi

export HYPRLAND_INSTANCE_SIGNATURE="$signature"

# --- restart ----------------------------------------------------------------
if [ "$restart" = 1 ]; then
  # Match only this repo, never a bare `quickshell` (that pattern also matches the
  # shell running the kill).
  pkill -f "$qs_bin -p $here" 2>/dev/null || true
fi

# --- portal app info -----------------------------------------------------------
# Qt registers the app id "org.quickshell" with the host portal on startup. The
# portal resolves app info from a desktop file whose id matches, so without one it
# warns "App info not found for 'org.quickshell'" and skips the registration.
# Installing a hidden desktop entry is the whole fix; it costs one file and makes
# the warning go away instead of muting the log.
desktop_dir="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
desktop_file="$desktop_dir/org.quickshell.desktop"

if [ ! -f "$desktop_file" ] || ! grep -qx "Exec=$here/launch.sh" "$desktop_file" 2>/dev/null; then
  mkdir -p "$desktop_dir"
  cat > "$desktop_file" <<DESKTOP
[Desktop Entry]
Type=Application
Name=omashell
Comment=Quickshell bar from $here
Exec=$here/launch.sh
NoDisplay=true
Terminal=false
Categories=System;
DESKTOP
  echo "portal app info: wrote $desktop_file"
fi

echo "repo:      $here"
echo "qs:        $qs_bin"
echo "signature: $HYPRLAND_INSTANCE_SIGNATURE"

if [ "$echo_only" = 1 ]; then
  echo "+ $qs_bin -p $here"
  exit 0
fi

exec "$qs_bin" -p "$here"
