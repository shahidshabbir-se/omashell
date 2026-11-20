#!/usr/bin/env bash
# Compare the actual rendered crop at multiple Wayland output scales.
# Requires headless-capable sway, quickshell, grim, and Python Pillow.
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)
tmp=$(mktemp -d)
sway_pid=; shell_pid=
stop() {
  if [[ -n $shell_pid ]]; then kill "$shell_pid" 2>/dev/null || true; wait "$shell_pid" 2>/dev/null || true; fi
  if [[ -n $sway_pid ]]; then kill "$sway_pid" 2>/dev/null || true; wait "$sway_pid" 2>/dev/null || true; fi
  shell_pid=; sway_pid=
}
cleanup() { stop; rm -rf -- "$tmp"; }
trap cleanup EXIT
mkdir -p "$tmp/gallery" "$tmp/bin"
cp -a "$repo"/{common,config,modules} "$tmp/"
printf '%s\n' '#!/usr/bin/env bash' 'exit 1' > "$tmp/bin/awww"
chmod +x "$tmp/bin/awww"
export PATH="$tmp/bin:$PATH" GALLERY="$tmp/gallery" XDG_CACHE_HOME="$tmp/cache" XDG_DATA_HOME="$tmp/data"
export WLR_BACKENDS=headless WLR_RENDERER=pixman WLR_LIBINPUT_NO_DEVICES=1 QT_QPA_PLATFORM=wayland
unset WAYLAND_DISPLAY SWAYSOCK HYPRLAND_INSTANCE_SIGNATURE QT_SCALE_FACTOR QT_SCREEN_SCALE_FACTORS
python3 - "$GALLERY/grid.png" <<'PY'
from PIL import Image
import sys
w, h = 768, 475
image = Image.new('RGB', (w, h))
image.putdata([(32 + x * 192 // (w - 1), 30 + y * 192 // (h - 1), 123)
               for y in range(h) for x in range(w)])
image.save(sys.argv[1])
PY
cat > "$tmp/shell.qml" <<'QML'
import QtQuick
import Quickshell
import qs.modules.wallpaper
ShellRoot {
  WallpaperPanel {
    id: panel
    color: "black"
    reduceMotion: true
    library: ({sources: [Quickshell.env("GALLERY")]})
    onCenterReadyChanged: if (centerReady) settle.restart()
  }
  Timer { interval: 150; running: true; onTriggered: panel.toggle() }
  Timer { id: settle; interval: 400; onTriggered: console.info("PREVIEW READY") }
}
QML
for scale in 1 1.25 1.5 2; do
  XDG_RUNTIME_DIR="$tmp/runtime-$scale"
  export XDG_RUNTIME_DIR
  mkdir -m 700 "$XDG_RUNTIME_DIR"
  printf '%s\n' "output * resolution 1920x1200 scale $scale" 'seat * fallback true' 'xwayland disable' > "$tmp/sway.conf"
  sway -c "$tmp/sway.conf" >"$tmp/sway.log" 2>&1 & sway_pid=$!
  for _ in {1..60}; do
    socket=$(find "$XDG_RUNTIME_DIR" -maxdepth 1 -type s -name 'wayland-*' -printf '%f\n' | head -1)
    [[ -z $socket ]] || break
    sleep .1
  done
  export WAYLAND_DISPLAY=${socket:?failed to start headless compositor}
  quickshell -p "$tmp" >"$tmp/quickshell.log" 2>&1 & shell_pid=$!
  for _ in {1..60}; do
    if grep -q 'PREVIEW READY' "$tmp/quickshell.log"; then break; fi
    sleep .1
  done
  grep -q 'PREVIEW READY' "$tmp/quickshell.log" || { cat "$tmp/quickshell.log" >&2; exit 1; }
  grim "$tmp/render.png"
  python3 - "$tmp/render.png" "$scale" <<'PY'
from PIL import Image
import sys
scale = float(sys.argv[2])
image = Image.open(sys.argv[1]).convert('RGB')
w, h = image.size
is_texture = lambda px: abs(px[2] - 123) <= 8 and px[0] > 20 and px[1] > 20
xs = [x for x in range(w) if is_texture(image.getpixel((x, h // 2)))]
ys = [y for y in range(h) if is_texture(image.getpixel((w // 2, y)))]
assert xs and ys, f'{scale}×: preview was not rendered'
assert abs((ys[-1] - ys[0]) / scale - 475) < 5, f'{scale}×: preview height is incorrect'
for fy in (0.28, 0.63, 0.84):
    for fx in (0.27, 0.60, 0.86):
        actual = image.getpixel((round(xs[0] + fx * (xs[-1] - xs[0])), round(ys[0] + fy * (ys[-1] - ys[0]))))
        expected = (32 + fx * 192, 30 + fy * 192, 123)
        assert all(abs(a - b) <= 9 for a, b in zip(actual, expected)), (
            f'{scale}×: distorted crop at ({fx}, {fy}), expected about {expected}, got {actual}')
print(f'PASS: preview crop at {scale}×')
PY
  stop
  unset WAYLAND_DISPLAY
done
