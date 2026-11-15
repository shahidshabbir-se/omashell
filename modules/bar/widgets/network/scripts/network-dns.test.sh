#!/usr/bin/env bash
set -euo pipefail
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

cat > "$tmp/ip" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' '1.1.1.1 via 192.0.2.1 dev wlan0 src 192.0.2.2'
EOF
cat > "$tmp/nmcli" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  *GENERAL.CONNECTION*) printf '%s\n' 'Test Wi-Fi' ;;
  *ipv4.ignore-auto-dns*) printf '%s\n' yes ;;
  *ipv4.dns*) printf '%s\n' '8.8.8.8,8.8.4.4' ;;
  *ipv6.dns*) printf '%s\n' '2001:4860:4860::8888,2001:4860:4860::8844' ;;
  *) exit 1 ;;
esac
EOF
chmod +x "$tmp/ip" "$tmp/nmcli"
output=$(PATH="$tmp:$PATH" bash "$here/network-dns.sh")
[[ $output == *$'provider\tGoogle'* ]] || { printf 'Expected Google, got: %s\n' "$output" >&2; exit 1; }
printf 'Network DNS helper tests passed\n'
