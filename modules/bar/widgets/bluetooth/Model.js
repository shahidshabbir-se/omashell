// Pure helpers for the bluetooth panel: turning Quickshell's device objects into
// the plain rows the view binds to. No Qt types and no state, so the panel stays a
// view and it alone owns the actions.

function toArray(values) {
  if (!values) return []
  if (Array.isArray(values)) return values.slice()

  var length = Number(values.length || 0)
  if (!isFinite(length) || length <= 0) return []

  var list = []
  for (var i = 0; i < length; i++) list.push(values[i])
  return list
}

function label(device) {
  if (!device) return ""
  return String(device.deviceName || device.name || "").trim()
}

function address(device) {
  return device ? String(device.address || "").trim() : ""
}

function normalizedAddress(value) {
  return String(value || "").trim().toUpperCase().replace(/-/g, ":")
}

function isAddressLike(value) {
  return /^[0-9A-F]{2}(:[0-9A-F]{2}){5}$/.test(normalizedAddress(value))
}

function isUuidLike(value) {
  var v = String(value || "").trim().toLowerCase()
  var bare = v.replace(/-/g, "")
  if (bare.length < 16) return false
  return /^[0-9a-f]+$/.test(bare) && bare.indexOf(":") === -1
}

// Plenty of devices advertise only a uuid, or their own address, as a name.
// Showing the address is less confusing than showing either of those.
function hasHumanName(device) {
  var name = label(device)
  if (name === "") return false
  if (isAddressLike(name)) return false
  if (isUuidLike(name)) return false
  return true
}

// Match the Bluetooth panel's row glyphs: the connected mark for active
// devices and the plain Bluetooth mark for paired/discovered devices.
function glyphFor(device) {
  return device && device.connected ? "\uDB80\uDCB1" : "\uDB80\uDCAF"
}

function batteryPercent(device) {
  if (!device || !device.batteryAvailable) return -1
  var value = Number(device.battery)
  if (!isFinite(value)) return -1
  return Math.round(value * 100)
}

function sectionOf(device) {
  if (!device) return ""
  if (device.connected) return "connected"
  if (device.paired || device.bonded || device.trusted) return "known"
  return "discovered"
}

function rowFor(device, section) {
  return {
    address: normalizedAddress(address(device)),
    label: hasHumanName(device) ? label(device) : (address(device) || "Unknown device"),
    glyph: glyphFor(device),
    battery: batteryPercent(device),
    connected: !!device.connected,
    paired: !!(device.paired || device.bonded || device.trusted),
    section: section
  }
}

function sortedRows(rows) {
  return rows.sort(function(left, right) {
    return String(left.label).toLowerCase().localeCompare(String(right.label).toLowerCase())
  })
}

// connected / known / discovered, each sorted, as plain rows.
function deviceLists(devices) {
  var out = { connected: [], known: [], discovered: [] }
  var list = toArray(devices)

  for (var i = 0; i < list.length; i++) {
    // A device advertising only an address or a uuid is not worth a row: it reads
    // as a serial number and there is nothing to recognise. Same filter Omarchy's
    // model applies.
    if (!hasHumanName(list[i])) continue
    var section = sectionOf(list[i])
    if (section === "") continue
    out[section].push(rowFor(list[i], section))
  }

  out.connected = sortedRows(out.connected)
  out.known = sortedRows(out.known)
  out.discovered = sortedRows(out.discovered)
  return out
}

function statusText(row, pending) {
  if (pending) return actionLabel(pending)
  if (!row) return ""
  // Omarchy shows battery only for connected devices.
  if (row.connected && row.battery >= 0) return String(row.battery) + "%"
  // Omarchy only shows a secondary line when it has live battery or action
  // state; connected/paired membership is already conveyed by the section.
  return ""
}

// What acting on a row does: connected rows disconnect, known rows connect,
// freshly discovered ones pair (and then connect).
function actionFor(row) {
  if (!row) return ""
  if (row.section === "connected") return "disconnect"
  if (row.section === "known") return "connect"
  return "pair"
}

function actionWord(action) {
  if (action === "connect") return "Connect"
  if (action === "disconnect") return "Disconnect"
  if (action === "pair") return "Pair"
  if (action === "forget") return "Forget"
  return ""
}

function actionLabel(action) {
  if (action === "connect") return "Connecting…"
  if (action === "disconnect") return "Disconnecting…"
  if (action === "pair") return "Connecting…"
  if (action === "forget") return "Forgetting…"
  return ""
}

function withPending(map, address, action) {
  var next = ({})
  for (var key in map) next[key] = map[key]
  next[normalizedAddress(address)] = action
  return next
}

// Retain pending labels until BlueZ confirms the target state, rather than
// trusting bluetoothctl's process lifetime (which can outlive a successful link).
function syncPending(map, devices) {
  var next = ({})
  var list = toArray(devices)
  for (var address in map || {}) {
    var action = map[address]
    var found = null
    for (var i = 0; i < list.length; i++) {
      if (normalizedAddress(list[i] && list[i].address) === normalizedAddress(address)) {
        found = list[i]
        break
      }
    }

    var complete = false
    if (action === "connect" || action === "pair") complete = !!(found && found.connected)
    else if (action === "disconnect") complete = !found || !found.connected
    else if (action === "forget") complete = !found || !(found.paired || found.bonded || found.trusted)
    if (!complete) next[normalizedAddress(address)] = action
  }
  return next
}

function withoutPending(map, address) {
  var next = ({})
  var drop = normalizedAddress(address)
  for (var key in map) if (normalizedAddress(key) !== drop) next[key] = map[key]
  return next
}

if (typeof module !== "undefined") {
  module.exports = {
    normalizedAddress: normalizedAddress,
    statusText: statusText,
    actionLabel: actionLabel,
    withPending: withPending,
    withoutPending: withoutPending,
    syncPending: syncPending
  }
}
