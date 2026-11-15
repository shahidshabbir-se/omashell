#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/../../../.." && pwd)
qml=$(mktemp "$root/.audio-test-XXXXXX.qml")
state=$(mktemp -d)
trap 'rm -f "$qml"; rm -rf "$state"' EXIT
cp "$root/modules/bar/widgets/audio/test_audio.qml" "$qml"
XDG_STATE_HOME="$state" timeout 8s qs -p "$qml"
