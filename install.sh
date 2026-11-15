#!/usr/bin/env bash
set -euo pipefail

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
target=${OMASHELL_INSTALL_DIR:-${XDG_DATA_HOME:-${HOME:?}/.local/share}/omashell}
service_target=graphical-session.target
check_only=false
uninstall=false
enable_service=false
disable_service=false

usage() {
  printf '%s\n' \
    'Usage: ./install.sh [--prefix DIR] [--check] [--enable-service [--target TARGET]]' \
    '       ./install.sh [--prefix DIR] --disable-service' \
    '       ./install.sh [--prefix DIR] --uninstall' \
    '' \
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
  if has_shell; then printf '  required: Quickshell ✓\n'; else printf '  required: qs/quickshell MISSING\n'; missing=1; fi
  for command_name in hyprctl jq; do
    if command -v "$command_name" >/dev/null 2>&1; then printf '  required: %s ✓\n' "$command_name"; else printf '  required: %s MISSING\n' "$command_name"; missing=1; fi
  done
  for command_name in nmcli curl wpctl pactl cava upower powerprofilesctl bluetoothctl wl-copy qrencode ip xdg-open omasnap; do
    if command -v "$command_name" >/dev/null 2>&1; then printf '  optional: %s ✓\n' "$command_name"; else printf '  optional: %s not found\n' "$command_name"; fi
  done
  return "$missing"
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

mkdir -p -- "$parent" "$bin_home"
stage=$(mktemp -d "$parent/.omashell-stage.XXXXXX")
backup=''
cleanup() {
  if [[ -n $stage ]]; then rm -rf -- "$stage"; fi
  if [[ -n $backup && -d $backup && ! -e $target ]]; then mv -- "$backup" "$target"; fi
}
trap cleanup EXIT
cp -a -- "$here/assets" "$here/common" "$here/config" "$here/modules" "$here/bin" "$here/shell.qml" "$stage/"
printf '%s\n' 'omashell-user-install-v1' > "$stage/.omashell-install"

if [[ -e $target ]]; then
  backup="$target.backup.$BASHPID"
  mv -- "$target" "$backup"
fi
mv -- "$stage" "$target"
stage=''
ln -sfn -- "$target/bin/omashell" "$link"
if [[ -n $backup ]]; then rm -rf -- "$backup"; backup=''; fi

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
