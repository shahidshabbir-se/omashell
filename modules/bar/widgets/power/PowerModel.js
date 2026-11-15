function batteryIcon(fraction, onBattery, full, threshold) {
  var level = Number(fraction)
  if (!isFinite(level)) level = 0
  var index = Math.min(9, Math.max(0, Math.floor(level * 10)))
  var battery = ['󰁺', '󰁻', '󰁼', '󰁽', '󰁾', '󰁿', '󰂀', '󰂁', '󰂂', '󰁹']
  var charging = ['󰢜', '󰂆', '󰂇', '󰂈', '󰢝', '󰂉', '󰢞', '󰂊', '󰂋', '󰂅']
  if (threshold || onBattery) return battery[index]
  if (full) return '󰂅'
  return charging[index]
}

function chargeThresholdActive(fraction, onBattery, state, rate, timeToFull, limit, states) {
  if (onBattery || state === states.Discharging) return false
  if (state === states.PendingCharge) return true
  if (limit === null || limit === undefined || !isFinite(Number(limit)) || Number(limit) >= 99) return false
  if (state === states.FullyCharged) return fraction < 0.99
  return state === states.Charging && fraction < 0.99 && (Number(rate || 0) <= 0.2 || Number(timeToFull || 0) >= 28800)
}

if (typeof module !== 'undefined') module.exports = { batteryIcon: batteryIcon, chargeThresholdActive: chargeThresholdActive }
