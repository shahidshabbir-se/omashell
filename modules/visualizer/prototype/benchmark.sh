#!/usr/bin/env bash
# THROWAWAY: compares rendering approaches on the current Wayland desktop.
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
command -v quickshell >/dev/null || { echo 'quickshell not found on PATH' >&2; exit 1; }
command -v nvidia-smi >/dev/null || { echo 'nvidia-smi required for this prototype' >&2; exit 1; }
mapfile -t paused < <(ps -eo pid=,args= | awk '($2 ~ /\/(quickshell|qs)$/ && $3 == "-p" && $4 ~ /omashell/) || ($2 ~ /\/cava$/ && $3 == "-p" && $4 ~ /visualizer\/cava.conf$/) {print $1}')
child=
log=$(mktemp)
cleanup() {
  [[ -z $child ]] || { kill "$child" 2>/dev/null || true; wait "$child" 2>/dev/null || true; }
  for pid in "${paused[@]}"; do kill -CONT "$pid" 2>/dev/null || true; done
  rm -f "$log"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
for pid in "${paused[@]}"; do
  kill -STOP "$pid" 2>/dev/null || true
  printf 'Paused process %s\n' "$pid"
done
sleep 2
for mode in baseline current optimized current optimized compact rate30 baseline; do
  printf '%-10s ' "$mode"
  VISUALIZER_PROTOTYPE_MODE="$mode" quickshell -p "$here/VisualizerPrototype.qml" >"$log" 2>&1 &
  child=$!
  sleep 2
  if ! kill -0 "$child" 2>/dev/null; then
    echo 'prototype failed to start' >&2
    grep -E 'ERROR|WARN' "$log" >&2 || true
    exit 1
  fi
  timeout 5 nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits -l 1 2>/dev/null |
    awk '{sum+=$1; n++; printf "%s%% ", $1} END {if (n) printf "mean=%.1f%% n=%d\n", sum/n, n}' || true
  kill "$child" 2>/dev/null || true
  wait "$child" 2>/dev/null || true
  child=
done
