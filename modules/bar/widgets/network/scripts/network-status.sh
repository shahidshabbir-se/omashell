#!/usr/bin/env bash







set -uo pipefail

probe=1.1.1.1
verbose=false

case "${1:-}" in
"") ;;
--verbose) verbose=true ;;
*)
  printf 'Usage: network-status.sh [--verbose]\n' >&2
  exit 2
  ;;
esac

route_device() {
  ip route get "$probe" 2>/dev/null |
    awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }'
}

route_token() {
  awk -v key="$2" '{ for (i = 1; i <= NF; i++) if ($i == key) { print $(i + 1); exit } }' <<<"$1"
}

nm_get() {
  LC_ALL=C nmcli -e no -g "$@" 2>/dev/null
}

                                                                             
                            
iw_link_field() {
  local device=$1 key=$2
  iw dev "$device" link 2>/dev/null | awk -v key="$key" '
    index($0, key ":") > 0 { sub(/^.*: /, ""); print; exit }'
}

                                                                              
                                                             
nm_wifi_in_use() {
  local device=$1 row
  row=$(LC_ALL=C nmcli -e no -t -f IN-USE,FREQ,SSID dev wifi list ifname "$device" --rescan no 2>/dev/null |
    awk -F: '$1 == "*" { print; exit }')
  [[ -n $row ]] || return 0
  printf '%s\n' "$row"
}

print_status() {
  local device state ssid signal freq

  device=$(route_device)
  if [[ -z $device ]]; then
    printf 'disconnected\t\t\t\n'
    return
  fi

  if [[ ! -d /sys/class/net/$device/wireless ]]; then
    printf 'ethernet\t%s\t\t\n' "$device"
    return
  fi

  state=$(nm_get GENERAL.STATE dev show "$device" | head -n 1)
  ssid=$(nm_get GENERAL.CONNECTION dev show "$device" | head -n 1)

  if command -v iw >/dev/null 2>&1; then
    signal=$(iw_link_field "$device" signal)
    signal=${signal% dBm}
    freq=$(iw_link_field "$device" freq)
  fi

  if [[ -z ${ssid:-} || -z ${freq:-} ]]; then
    local row rest
    row=$(nm_wifi_in_use "$device")
    if [[ -n $row ]]; then
      rest=${row#*:}
      [[ -n ${freq:-} ]] || freq=${rest%%:*}
      [[ -n ${ssid:-} ]] || ssid=${rest#*:}
      [[ -n ${signal:-} ]] || signal=$(nm_get IN-USE,SIGNAL dev wifi list ifname "$device" --rescan no |
        awk -F: '$1 == "*" { print $2; exit }')
    fi
  fi

                                                                       
  if [[ ${state:-} != 100* && ${state:-} != "" ]]; then
    printf 'disconnected\t\t\t\n'
    return
  fi

  printf 'wifi\t%s\t%s\t%s\n' "${ssid:-$device}" "${signal:-}" "${freq:-}"
}

ping_latency_ms() {
  local host=$1
  LC_ALL=C ping -n -c 1 -W 1 "$host" 2>/dev/null |
    awk -F'time[=<]' '/time[=<]/ { split($2, parts, " "); print parts[1]; exit }'
}

print_ping_samples() {
  local gateway=$1
  local tmpdir router_file internet_file router_pid=""

  command -v ping >/dev/null 2>&1 || return 0
  tmpdir=$(mktemp -d) || return 0
  router_file="$tmpdir/router"
  internet_file="$tmpdir/internet"

  if [[ -n $gateway ]]; then
    ping_latency_ms "$gateway" >"$router_file" &
    router_pid=$!
  fi

  ping_latency_ms "$probe" >"$internet_file" &
  local internet_pid=$!

  if [[ -n $router_pid ]]; then
    wait "$router_pid"
    printf 'router_ping_ms\t%s\n' "$(cat "$router_file")"
  fi
  wait "$internet_pid"
  printf 'internet_ping_ms\t%s\n' "$(cat "$internet_file")"
  rm -rf "$tmpdir"
}

print_verbose() {
  local route iface gateway src prefix

  route=$(ip route get "$probe" 2>/dev/null)
  [[ -n $route ]] || return 0

  iface=$(route_token "$route" dev)
  gateway=$(route_token "$route" via)
  src=$(route_token "$route" src)
  [[ -n $iface ]] || return 0

  printf 'iface\t%s\n' "$iface"
  printf 'ip\t%s\n' "$src"
  printf 'gateway\t%s\n' "$gateway"

  prefix=$(ip -o addr show dev "$iface" 2>/dev/null |
    awk '{ for (i = 1; i <= NF; i++) if ($i == "inet") { split($(i + 1), parts, "/"); print parts[2]; exit } }')
  [[ -n $prefix ]] && printf 'prefix\t%s\n' "$prefix"

  [[ -r /sys/class/net/$iface/statistics/rx_bytes ]] &&
    printf 'rx_bytes\t%s\n' "$(cat /sys/class/net/$iface/statistics/rx_bytes)"
  [[ -r /sys/class/net/$iface/statistics/tx_bytes ]] &&
    printf 'tx_bytes\t%s\n' "$(cat /sys/class/net/$iface/statistics/tx_bytes)"

  if [[ -d /sys/class/net/$iface/wireless ]]; then
    printf 'type\twifi\n'
    if command -v iw >/dev/null 2>&1; then
      local ssid freq bitrate
      ssid=$(iw_link_field "$iface" SSID)
      freq=$(iw_link_field "$iface" freq)
      bitrate=$(iw dev "$iface" link 2>/dev/null |
        awk '/tx bitrate:/ { print $3 " " $4; exit }')
      [[ -n $ssid ]] && printf 'ssid\t%s\n' "$ssid"
      [[ -n $freq ]] && printf 'freq\t%s\n' "$freq"
      [[ -n $bitrate ]] && printf 'bitrate\t%s\n' "$bitrate"
    fi
  else
    printf 'type\tethernet\n'
    local speed duplex
    speed=$(cat /sys/class/net/$iface/speed 2>/dev/null || true)
    duplex=$(cat /sys/class/net/$iface/duplex 2>/dev/null || true)
    [[ -n $speed && $speed != "-1" ]] && printf 'speed\t%s\n' "$speed"
    [[ -n $duplex ]] && printf 'duplex\t%s\n' "$duplex"
  fi

  print_ping_samples "$gateway"
}

if [[ $verbose == true ]]; then
  print_verbose
else
  print_status
fi
