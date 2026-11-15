#!/usr/bin/env bash
                                                                                
 
                                                                            
                                                                          
                                                                             
                                                                              
                                                                           
                            

set -euo pipefail

usage() {
  echo "Usage: network-dns.sh [DHCP|Cloudflare|Google|Custom] [servers]" >&2
}

nm_get() {
  LC_ALL=C nmcli -e no -g "$@" 2>/dev/null
}

active_interface() {
  local iface
  iface=$(ip route get 1.1.1.1 2>/dev/null |
    awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }')
  [[ -n $iface ]] && {
    echo "$iface"
    return 0
  }
  LC_ALL=C nmcli -t -f DEVICE,TYPE,STATE device status 2>/dev/null |
    awk -F: '($2 == "wifi" || $2 == "ethernet") && $3 ~ /^connected/{ print $1; exit }'
}

active_profile() {
  local iface=$1
  nm_get GENERAL.CONNECTION device show "$iface" | head -n 1
}

split_families() {
  ipv4=""
  ipv6=""
  local server
  for server in ${1//,/ }; do
    [[ -n $server ]] || continue
    if [[ $server == *:* ]]; then
      ipv6+="${ipv6:+ }$server"
    else
      ipv4+="${ipv4:+ }$server"
    fi
  done
}

profile_servers() {
  local profile=$1 v4 v6
  v4=$(nm_get ipv4.dns connection show "$profile")
  v6=$(nm_get ipv6.dns connection show "$profile")
  printf '%s %s' "$v4" "$v6" | tr -s ' ,' ' ' | sed 's/^ //; s/ $//'
}

classify() {
  local servers=$1 ignore=$2 compact has_cloudflare=1 has_google=1 token
  compact=$(printf '%s' "$servers" | tr -d '[:space:],')

  if [[ $ignore != "yes" || -z $compact ]]; then
    echo "DHCP"
    return
  fi

  for token in ${servers//,/ }; do
    case "$token" in
    1.1.1.1 | 1.0.0.1 | 2606:4700:4700::1111 | 2606:4700:4700::1001 | dns.cloudflare.com) ;;
    *) has_cloudflare=0 ;;
    esac
    case "$token" in
    8.8.8.8 | 8.8.4.4 | 2001:4860:4860::8888 | 2001:4860:4860::8844 | dns.google) ;;
    *) has_google=0 ;;
    esac
  done

  if ((has_cloudflare == 1)); then
    echo "Cloudflare"
  elif ((has_google == 1)); then
    echo "Google"
  else
    echo "Custom"
  fi
}

flush_dns_cache() {
  command -v resolvectl >/dev/null 2>&1 && resolvectl flush-caches >/dev/null 2>&1 || true
}

reapply() {
  local iface=$1 profile=$2
  if ! nmcli device reapply "$iface" >/dev/null 2>&1; then
    nmcli connection up "$profile" >/dev/null 2>&1 || {
      echo "Error: the new DNS settings were saved but could not be applied." >&2
      exit 1
    }
  fi
  flush_dns_cache
}

if (($# == 0)); then
  interface=$(active_interface || true)
  [[ -n ${interface:-} ]] || {
    echo "Error: no active network connection" >&2
    exit 1
  }
  profile=$(active_profile "$interface")
  [[ -n $profile ]] || {
    echo "Error: no active NetworkManager profile" >&2
    exit 1
  }
  servers=$(profile_servers "$profile")
  ignore=$(nm_get ipv4.ignore-auto-dns connection show "$profile")
  printf 'provider\t%s\n' "$(classify "$servers" "$ignore")"
  printf 'servers\t%s\n' "${servers// /,}"
  printf 'profile\t%s\n' "$profile"
  exit 0
fi

provider=${1:-}
(( $# <= 2 )) || {
  usage
  exit 1
}

interface=$(active_interface || true)
[[ -n ${interface:-} ]] || {
  echo "Error: no active network connection" >&2
  exit 1
}
profile=$(active_profile "$interface")
[[ -n $profile ]] || {
  echo "Error: no active NetworkManager profile" >&2
  exit 1
}

cancel_override() {
  nmcli connection modify "$profile" \
    ipv4.ignore-auto-dns no ipv6.ignore-auto-dns no \
    ipv4.dns "" ipv6.dns "" >/dev/null || {
    echo "Error: could not clear the DNS override (permission or profile problem)." >&2
    exit 1
  }
  reapply "$interface" "$profile"
}

set_servers() {
  local servers=$1
  split_families "$servers"
  [[ -n $ipv4 || -n $ipv6 ]] || {
    echo "Error: no usable DNS servers given." >&2
    exit 1
  }
  nmcli connection modify "$profile" \
    ipv4.ignore-auto-dns yes ipv4.dns "${ipv4// /,}" \
    ipv6.ignore-auto-dns yes ipv6.dns "${ipv6// /,}" >/dev/null || {
    echo "Error: could not set the DNS servers (permission or profile problem)." >&2
    exit 1
  }
  reapply "$interface" "$profile"
}

case "${provider,,}" in
dhcp)
  cancel_override
  ;;
cloudflare)
  set_servers "1.1.1.1,1.0.0.1,2606:4700:4700::1111,2606:4700:4700::1001"
  ;;
google)
  set_servers "8.8.8.8,8.8.4.4,2001:4860:4860::8888,2001:4860:4860::8844"
  ;;
custom)
  [[ $# == 2 && -n ${2:-} ]] || {
    echo "Error: Custom needs a list of DNS servers." >&2
    exit 1
  }
  set_servers "$2"
  ;;
*)
  usage
  exit 1
  ;;
esac
