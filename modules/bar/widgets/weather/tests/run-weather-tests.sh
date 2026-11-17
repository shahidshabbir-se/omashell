#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/root" "$tmp/bin" "$tmp/runtime"
chmod 700 "$tmp/runtime"
ln -s "$repo/modules" "$tmp/root/modules"
cp "$repo/modules/bar/widgets/weather/tests/WeatherHarness.qml" "$tmp/root/shell.qml"
cat > "$tmp/bin/curl" <<'MOCK'
#!/usr/bin/env bash
case "$*" in
  *ipinfo.io*) printf '%s' '{"city":"Faisalabad","country":"PK","loc":"31.45,73.13"}' ;;
  *api.open-meteo.com*)
    if [[ "$WEATHER_TEST_CASE" == primary ]]; then
      printf '%s' '{"current":{"temperature_2m":25},"daily":{"time":["2026-01-01"],"weather_code":[0],"temperature_2m_max":[30],"temperature_2m_min":[20]}}'
    elif [[ "$WEATHER_TEST_CASE" == invalid-primary ]]; then printf '%s' '{}'
    else exit 22; fi ;;
  *wttr.in*)
    if [[ "$WEATHER_TEST_CASE" == both-fail ]]; then exit 22; fi
    printf '%s' '{"current_condition":[{"temp_C":"25","FeelsLikeC":"26","humidity":"50","windspeedKmph":"10","weatherCode":"113"}],"weather":[{"date":"2026-01-01","maxtempC":"30","mintempC":"20","hourly":[{"time":"1200","weatherCode":"113"}]}]}' ;;
  *) exit 1 ;;
esac
MOCK
chmod +x "$tmp/bin/curl"
export PATH="$tmp/bin:$PATH" QT_QPA_PLATFORM=offscreen XDG_RUNTIME_DIR="$tmp/runtime"
unset WAYLAND_DISPLAY HYPRLAND_INSTANCE_SIGNATURE || true
for case_name in primary fallback invalid-primary both-fail; do
  if ! WEATHER_TEST_CASE="$case_name" timeout 10 "${QUICKSHELL:-quickshell}" -p "$tmp/root/shell.qml" >"$tmp/log" 2>&1 || ! grep -q 'TEST PASS' "$tmp/log"; then
    printf 'FAIL: %s\n' "$case_name"
    cat "$tmp/log"
    exit 1
  fi
  printf 'ok: %s\n' "$case_name"
done
