#!/usr/bin/env bash
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
target=${OMASHELL_INSTALL_DIR:-${XDG_DATA_HOME:-${HOME:?}/.local/share}/omashell}
service_target=graphical-session.target
check_only=false
uninstall=false
enable_service=false
disable_service=false
integrate_display=true
wallpaper_selection=prompt
wallpaper_themes=

usage() {
  printf '%s\n' \
    'Usage: ./install.sh [--prefix DIR] [--check] [--enable-service [--target TARGET]]' \
    '       ./install.sh [--prefix DIR] --disable-service' \
    '       ./install.sh [--prefix DIR] --uninstall' \
    '' \
    'Use --omarchy-wallpapers all|THEME[,THEME...] to download backgrounds without prompting.' \
    'Use --no-omarchy-wallpapers to skip the download prompt.' \
    'Use --no-display-integration to leave your Hyprland Lua config untouched.' \
    'Installs or updates Omashell for the current user. User config and state are kept on uninstall.'
}

while (($#)); do
  case "$1" in
    --prefix)
      (($# >= 2)) || { usage >&2; exit 2; }
      target=$2
      shift 2
      ;;
    --target)
      (($# >= 2)) || { usage >&2; exit 2; }
      service_target=$2
      shift 2
      ;;
    --omarchy-wallpapers)
      (($# >= 2)) && [[ -n $2 && $2 != -* ]] || { usage >&2; exit 2; }
      wallpaper_selection=explicit
      wallpaper_themes=$2
      shift 2
      ;;
    --no-omarchy-wallpapers) wallpaper_selection=skip; shift ;;
    --no-display-integration) integrate_display=false; shift ;;
    --check) check_only=true; shift ;;
    --enable-service) enable_service=true; shift ;;
    --disable-service) disable_service=true; shift ;;
    --uninstall) uninstall=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'install.sh: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
done

case "$service_target" in
  *[!A-Za-z0-9_.@:-]*|'') printf 'install.sh: invalid systemd target: %s\n' "$service_target" >&2; exit 2 ;;
esac
if [[ $enable_service == true && $disable_service == true ]]; then
  printf '%s\n' 'install.sh: --enable-service and --disable-service cannot be combined.' >&2
  exit 2
fi

if [[ -L $target ]]; then
  printf 'install.sh: refusing symlink installation path: %s\n' "$target" >&2
  exit 2
fi
target=$(realpath -m -- "$target")
parent=$(dirname -- "$target")
if [[ $target == / || $target == "$HOME" ]]; then
  printf '%s\n' 'install.sh: refusing to use the home directory as the installation directory.' >&2
  exit 2
fi
bin_home=${XDG_BIN_HOME:-${HOME:?}/.local/bin}
link=$bin_home/omashell
service_dir=${XDG_CONFIG_HOME:-${HOME:?}/.config}/systemd/user
service_file=$service_dir/omashell.service

has_shell() { command -v qs >/dev/null 2>&1 || command -v quickshell >/dev/null 2>&1; }
check_dependencies() {
  local missing=0 command_name
  for command_name in bash python3 realpath readlink; do
    if command -v "$command_name" >/dev/null 2>&1; then printf '  required: %s ✓\n' "$command_name"; else printf '  required: %s MISSING\n' "$command_name"; missing=1; fi
  done
  if ! python3 -c 'import PIL' >/dev/null 2>&1; then
    printf '%s\n' '  optional: Python Pillow not found (wallpaper previews will not use the disk cache)'
  fi
  if has_shell; then printf '  required: Quickshell ✓\n'; else printf '  required: qs/quickshell MISSING\n'; missing=1; fi
  for command_name in hyprctl jq wl-copy wl-paste; do
    if command -v "$command_name" >/dev/null 2>&1; then printf '  required: %s ✓\n' "$command_name"; else printf '  required: %s MISSING\n' "$command_name"; missing=1; fi
  done
  for command_name in nmcli curl wpctl pactl cava awww upower powerprofilesctl bluetoothctl qrencode ip xdg-open wtype; do
    if command -v "$command_name" >/dev/null 2>&1; then printf '  optional: %s ✓\n' "$command_name"; else printf '  optional: %s not found\n' "$command_name"; fi
  done

  if command -v omasnap >/dev/null 2>&1 || { [[ -f $target/.omasnap-install ]] && [[ -x $target/bin/omasnap ]]; }; then
    printf '  screenshot tool: omasnap ✓\n'
  else
    printf '  screenshot tool: omasnap will be built from its upstream release\n'
    for command_name in curl tar cmake make c++ pkg-config wayland-scanner; do
      if command -v "$command_name" >/dev/null 2>&1; then printf '  build requirement: %s ✓\n' "$command_name"; else printf '  build requirement: %s MISSING\n' "$command_name"; missing=1; fi
    done
    if command -v pkg-config >/dev/null 2>&1 && pkg-config --exists Qt6Concurrent Qt6Core Qt6Gui Qt6Test Qt6Widgets wayland-client libdeflate; then
      printf '  build libraries: Qt 6, Wayland, libdeflate ✓\n'
    else
      printf '  build libraries: Qt 6 (including Qt Test), Wayland, and libdeflate MISSING\n'
      missing=1
    fi
    if command -v cmake >/dev/null 2>&1 && cmake --find-package -DNAME=LayerShellQt -DCOMPILER_ID=GNU -DLANGUAGE=CXX -DMODE=EXIST >/dev/null 2>&1; then
      printf '  build library: LayerShellQt ✓\n'
    else
      printf '  build library: LayerShellQt MISSING\n'
      missing=1
    fi
    if [[ -f /usr/share/wayland-protocols/staging/ext-image-copy-capture/ext-image-copy-capture-v1.xml ]]; then
      printf '  protocol files: wayland-protocols ✓\n'
    else
      printf '  protocol files: wayland-protocols MISSING\n'
      missing=1
    fi
  fi
  return "$missing"
}

build_omasnap() {
  local destination="$1" work version jobs
  work=$(mktemp -d "${TMPDIR:-/tmp}/omashell-omasnap-build.XXXXXX")
  build_dirs+=("$work")
  version=$(curl -fsSL https://api.github.com/repos/omacom/omasnap/releases/latest \
    | jq -er '.tag_name | select(test("^v[0-9]+(\\.[0-9]+)+$"))')
  printf 'Building Omasnap %s from source...\n' "$version"
  mkdir -p "$work/source"
  curl -fsSL "https://github.com/omacom/omasnap/archive/refs/tags/$version.tar.gz" \
    | tar -xz --strip-components=1 -C "$work/source"
  python3 "$here/scripts/patch-omasnap-optional-notifier.py" "$work/source/src/capture.cpp"
  cmake -S "$work/source" -B "$work/build" -DCMAKE_BUILD_TYPE=Release -DOMASNAP_VERSION="${version#v}"
  jobs=${BUILD_JOBS:-$(getconf _NPROCESSORS_ONLN)}
  cmake --build "$work/build" --target omasnap --parallel "$jobs"
  install -m755 "$work/build/omasnap" "$destination"
}

if [[ $check_only == true ]]; then
  check_dependencies
  exit $?
fi

if [[ $uninstall == true ]]; then
  if [[ ! -f $target/.omashell-install ]]; then
    printf 'install.sh: refusing to remove unmarked directory %s\n' "$target" >&2
    exit 1
  fi
  if [[ -e $service_file ]] && grep -Fq '# Managed by Omashell install.sh' "$service_file" && grep -Fq "ExecStart=$target/bin/omashell" "$service_file"; then
    systemctl --user disable --now omashell.service >/dev/null 2>&1 || true
    rm -f -- "$service_file"
    systemctl --user daemon-reload >/dev/null 2>&1 || true
  fi
  if [[ -L $link && $(readlink -- "$link") == "$target/bin/omashell" ]]; then rm -- "$link"; fi
  if [[ -L $bin_home/omasnap && $(readlink -- "$bin_home/omasnap") == "$target/bin/omasnap" ]]; then rm -- "$bin_home/omasnap"; fi
  if [[ $integrate_display == true ]] && command -v python3 >/dev/null 2>&1; then
    python3 "$here/scripts/setup-display.py" --remove
  fi
  rm -rf -- "$target"
  printf 'Removed Omashell from %s; user config and state were left untouched.\n' "$target"
  exit 0
fi

if [[ $disable_service == true ]]; then
  if [[ -e $service_file ]] && grep -Fq '# Managed by Omashell install.sh' "$service_file" && grep -Fq "ExecStart=$target/bin/omashell" "$service_file"; then
    if ! command -v systemctl >/dev/null 2>&1; then
      printf '%s\n' 'install.sh: systemctl is required to disable the user service.' >&2
      exit 127
    fi
    systemctl --user disable --now omashell.service >/dev/null 2>&1 || true
    rm -f -- "$service_file"
    systemctl --user daemon-reload
    printf 'Removed the Omashell service for %s.\n' "$target"
  else
    printf 'No Omashell-managed service found for %s.\n' "$target"
  fi
  exit 0
fi

check_dependencies || {
  printf '%s\n' 'install.sh: missing required dependencies; install them with your distribution package manager, then retry.' >&2
  exit 1
}
if [[ $enable_service == true ]]; then
  if [[ $target == *[[:space:]]* ]]; then
    printf '%s\n' 'install.sh: service installation does not support whitespace in --prefix.' >&2
    exit 2
  fi
  if ! command -v systemctl >/dev/null 2>&1; then
    printf '%s\n' 'install.sh: systemctl is required to enable the user service.' >&2
    exit 127
  fi
  if [[ -e $service_file ]] && { [[ -L $service_file ]] || ! grep -Fq '# Managed by Omashell install.sh' "$service_file"; }; then
    printf 'install.sh: refusing to overwrite unmanaged service %s\n' "$service_file" >&2
    exit 1
  fi
fi

if [[ $target == "$here" || $target == "$here/"* ]]; then
  printf '%s\n' 'install.sh: installation directory must not be inside the source checkout.' >&2
  exit 2
fi
if [[ -e $target && ( -L $target || ! -f $target/.omashell-install ) ]]; then
  printf 'install.sh: refusing to replace unmarked directory %s\n' "$target" >&2
  exit 1
fi
if [[ -e $link && ! -L $link ]]; then
  printf 'install.sh: refusing to replace existing file %s\n' "$link" >&2
  exit 1
fi
if [[ -L $link && $(readlink -- "$link") != "$target/bin/omashell" ]]; then
  printf 'install.sh: %s is already a symlink to another target; remove it or choose a different bin directory.\n' "$link" >&2
  exit 1
fi

if { [[ -f $target/.omasnap-install ]] && [[ -x $target/bin/omasnap ]]; } || ! command -v omasnap >/dev/null 2>&1; then
  if [[ -e $bin_home/omasnap && ! -L $bin_home/omasnap ]]; then
    printf 'install.sh: refusing to replace existing file %s\n' "$bin_home/omasnap" >&2
    exit 1
  fi
  if [[ -L $bin_home/omasnap && $(readlink -- "$bin_home/omasnap") != "$target/bin/omasnap" ]]; then
    printf 'install.sh: %s is already a symlink to another Omasnap; remove it or install Omasnap separately.\n' "$bin_home/omasnap" >&2
    exit 1
  fi
fi

mkdir -p -- "$parent" "$bin_home"
stage=$(mktemp -d "$parent/.omashell-stage.XXXXXX")
backup=''
build_dirs=()
cleanup() {
  if [[ -n $stage ]]; then rm -rf -- "$stage"; fi
  if [[ -n $backup && -d $backup && ! -e $target ]]; then mv -- "$backup" "$target"; fi
  for build_dir in "${build_dirs[@]}"; do rm -rf -- "$build_dir"; done
}
trap cleanup EXIT
cp -a -- "$here/assets" "$here/common" "$here/config" "$here/modules" "$here/bin" "$here/shell.qml" "$stage/"
if [[ -f $target/.omasnap-install && -x $target/bin/omasnap ]]; then
  install -m755 "$target/bin/omasnap" "$stage/bin/omasnap"
  printf '%s\n' 'omashell-managed-omasnap-v1' > "$stage/.omasnap-install"
elif ! command -v omasnap >/dev/null 2>&1; then
  build_omasnap "$stage/bin/omasnap"
  printf '%s\n' 'omashell-managed-omasnap-v1' > "$stage/.omasnap-install"
fi
case "$wallpaper_selection" in
  explicit) python3 "$here/modules/wallpaper/import_omarchy.py" "$wallpaper_themes" ;;
  prompt)
    if [[ -t 0 && -t 1 ]]; then
      python3 "$here/modules/wallpaper/import_omarchy.py" ||
        printf '%s\n' 'Continuing without the remaining Omarchy wallpapers.' >&2
    fi
    ;;
esac
printf '%s\n' 'omashell-user-install-v1' > "$stage/.omashell-install"

if [[ -e $target ]]; then
  backup="$target.backup.$BASHPID"
  mv -- "$target" "$backup"
fi
mv -- "$stage" "$target"
stage=''
ln -sfn -- "$target/bin/omashell" "$link"
if [[ -f $target/.omasnap-install && -x $target/bin/omasnap ]]; then
  ln -sfn -- "$target/bin/omasnap" "$bin_home/omasnap"
fi
if [[ -n $backup ]]; then rm -rf -- "$backup"; backup=''; fi

if [[ $integrate_display == true ]]; then
  python3 "$here/scripts/setup-display.py"
fi

if [[ $enable_service == true ]]; then
  mkdir -p -- "$service_dir"
  cat > "$service_file" <<SERVICE
# Managed by Omashell install.sh
[Unit]
Description=Omashell Quickshell desktop shell
After=$service_target
PartOf=$service_target

[Service]
Type=simple
Environment=OMASHELL_ROOT=$target
Environment=QT_QPA_PLATFORM=wayland
ExecStart=$target/bin/omashell
Restart=on-failure
RestartSec=3

[Install]
WantedBy=$service_target
SERVICE
  systemctl --user daemon-reload
  systemctl --user enable --now omashell.service
fi

printf 'Installed Omashell in %s\n' "$target"
printf 'Launcher: %s\n' "$link"
printf 'Run ./bin/omashell for this checkout or omashell for the installed shell.\n'
