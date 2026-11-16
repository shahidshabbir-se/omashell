// Pure state, ordering, and geometry for the DND and stay-awake indicators.
// Qt-free so it can be unit tested under Node.
//
// The glyphs, tooltips, and status-slot geometry follow Omarchy's bar
// indicators (plugins/bar/indicators/Dnd.qml, StayAwake.qml and Ui/
// BarIndicator.qml; MIT, Copyright (c) David Heinemeier Hansson). Omashell
// keeps a portable state file instead of Omarchy's own state directory.

// Reference ids are "Dnd" and "StayAwake". The lowercase ids were Omashell's
// older spelling and still appear in existing shell.json files.
var DEFAULT_ITEMS = ["Dnd", "StayAwake"]
var SUPPORTED_IDS = ["Dnd", "StayAwake"]
var GLYPHS = {
  Dnd: "\u{f009b}",
  StayAwake: "\u{ef59}"
}

function itemId(item) {
  if (typeof item === "string") return item
  if (item && typeof item === "object" && item.id !== undefined && item.id !== null)
    return String(item.id)
  return ""
}

function normalizeId(value) {
  var text = String(value === undefined || value === null ? "" : value)
    .replace(/^\s+|\s+$/g, "")
    .toLowerCase()
  if (text.indexOf("omarchy.") === 0) text = text.slice("omarchy.".length)
  if (text === "dnd" || text === "notifications") return "Dnd"
  if (text === "stayawake" || text === "stay-awake" || text === "stay_awake") return "StayAwake"
  return ""
}

// An explicit non-empty selection is honored as written: if it names only
// indicators this independent bar does not implement, nothing shows. A
// missing selection, or an items list that is empty with no legacy
// indicators behind it, means the supported defaults, as in Omarchy.
function normalizeItems(items) {
  if (!Array.isArray(items) || items.length === 0) return DEFAULT_ITEMS.slice()
  var out = []
  for (var i = 0; i < items.length; i++) {
    var id = normalizeId(itemId(items[i]))
    if (id !== "" && out.indexOf(id) === -1) out.push(id)
  }
  return out
}

function itemsFromSettings(settings) {
  var source
  // As in the reference widget, an empty items list falls through to the
  // legacy indicators list before the built-in defaults apply.
  if (settings && Array.isArray(settings.items) && settings.items.length > 0) source = settings.items
  else if (settings && Array.isArray(settings.indicators) && settings.indicators.length > 0) source = settings.indicators
  return source === undefined ? DEFAULT_ITEMS.slice() : normalizeItems(source)
}

function glyphFor(id) {
  return GLYPHS[normalizeId(id)] || ""
}

function labelFor(id) {
  var normalized = normalizeId(id)
  if (normalized === "Dnd") return "Notifications"
  if (normalized === "StayAwake") return "Stay awake"
  return ""
}

function isActive(id, dnd, stayAwake) {
  var normalized = normalizeId(id)
  if (normalized === "Dnd") return dnd === true
  if (normalized === "StayAwake") return stayAwake === true
  return false
}

// The active block sits against the widget's fixed edge, and the revealed
// inactive block grows on the far side, so icons already showing keep their
// click targets.
function visibleItems(ids, dnd, stayAwake, revealInactive, fixedEdge) {
  var active = []
  var inactive = []
  var list = Array.isArray(ids) ? ids : []
  for (var i = 0; i < list.length; i++) {
    var id = normalizeId(list[i])
    if (id === "") continue
    var row = { id: id, active: isActive(id, dnd, stayAwake) }
    if (row.active) active.push(row)
    else if (revealInactive === true) inactive.push(row)
  }
  // A widget fixed at the start grows toward the end: its active block stays
  // first and its inactive block is mirrored outward. Every other fixed edge
  // grows toward the start, so the active block is mirrored instead, as the
  // reference bar does when a newly active indicator is inserted away from
  // the fixed edge.
  var orderedActive = fixedEdge === "start" ? active : active.slice().reverse()
  var orderedInactive = fixedEdge === "start" ? inactive.slice().reverse() : inactive
  return fixedEdge === "start"
    ? orderedActive.concat(orderedInactive)
    : orderedInactive.concat(orderedActive)
}

function indicatorOpacity(active, revealed) {
  if (active === true) return 1
  return revealed === true ? 0.45 : 0
}

function tooltipFor(id, active, supported) {
  var normalized = normalizeId(id)
  if (normalized === "Dnd")
    return active === true ? "Allow Notifications" : "Silence Notifications"
  if (normalized === "StayAwake") {
    if (supported === false) return "Stay-awake inhibition unavailable"
    return active === true ? "Allow Idle Lock & Screensaver" : "Stay Awake"
  }
  return ""
}

// BarIndicator geometry: status-slot width horizontally, bar-thickness width
// vertically, and a status-slot height vertically.
function buttonSize(vertical, barHeight, statusSlot) {
  // BarIndicator uses the bar thickness for a vertical button's width (the
  // vertical bar's icon slot), and the status slot for its height. Horizontal
  // buttons use the status slot for width and the bar thickness for height.
  return vertical
    ? { width: Number(barHeight), height: Number(statusSlot) }
    : { width: Number(statusSlot), height: Number(barHeight) }
}

// The whole widget's bar slot. Indicators sit in a gapless row or column.
function widgetSize(vertical, count, barHeight, statusSlot) {
  var n = Math.max(0, Number(count) || 0)
  return vertical
    ? { width: Number(barHeight), height: n * Number(statusSlot) }
    : { width: n * Number(statusSlot), height: Number(barHeight) }
}

// Portable stay-awake state file. Unlike Omarchy's ~/.local/state/omarchy,
// this lives under Omashell's own state directory and needs no Omarchy
// command to read or write.
function stateDirectory(xdgStateHome, home) {
  var state = String(xdgStateHome === undefined || xdgStateHome === null ? "" : xdgStateHome)
    .replace(/^\s+|\s+$/g, "")
  var base = state !== "" ? state : String(home === undefined || home === null ? "" : home) + "/.local/state"
  return base + "/omashell/indicators"
}

function statePath(xdgStateHome, home) {
  return stateDirectory(xdgStateHome, home) + "/stay-awake"
}

if (typeof module !== "undefined") {
  module.exports = {
    DEFAULT_ITEMS: DEFAULT_ITEMS,
    SUPPORTED_IDS: SUPPORTED_IDS,
    GLYPHS: GLYPHS,
    itemId: itemId,
    normalizeId: normalizeId,
    normalizeItems: normalizeItems,
    itemsFromSettings: itemsFromSettings,
    glyphFor: glyphFor,
    labelFor: labelFor,
    isActive: isActive,
    visibleItems: visibleItems,
    indicatorOpacity: indicatorOpacity,
    tooltipFor: tooltipFor,
    buttonSize: buttonSize,
    widgetSize: widgetSize,
    stateDirectory: stateDirectory,
    statePath: statePath
  }
}
