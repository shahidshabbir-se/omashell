// Pure clock format and date math. Qt-free so it can be unit tested under Node.
//
// Adapted from the Omarchy shell clock model (plugins/panels/clock/Model.js,
// MIT, Copyright (c) David Heinemeier Hansson). Omashell keeps only what the
// independent bar needs: the format rings, ISO week substitution, and the
// epoch-based timer arm.

var CLOCK_FORMATS = [
  "dddd HH:mm",
  "dddd h:mm AP",
  "dddd HH:mm:ss",
  "dddd h:mm:ss AP",
  "HH:mm",
  "h:mm AP",
  "ddd d MMM HH:mm",
  "ddd d MMM h:mm AP",
  "d MMMM 'W'ww yyyy",
  "yyyy-MM-dd HH:mm"
]

// A vertical bar has room for a few stacked lines and nothing else, so the
// ring stays short. AM/PM costs a fourth line, which only the plain time
// carries here.
var VERTICAL_CLOCK_FORMATS = [
  "HH\n—\nmm",
  "h\n—\nmm\nAP",
  "dd\nMMM\n'W'ww\n''yy",
  "HH\nmm"
]

var DEFAULT_HORIZONTAL_ALT_FORMAT = "d MMMM 'W'ww yyyy"
var DEFAULT_VERTICAL_ALT_FORMAT = "dd\nMMM\n'W'ww\n''yy"

function clockNeedsSeconds(format) {
  var text = String(format === undefined || format === null ? "" : format)
  return /s/.test(text.replace(/'[^']*'?/g, ""))
}

function clockFormats(vertical) {
  return vertical ? VERTICAL_CLOCK_FORMATS.slice() : CLOCK_FORMATS.slice()
}

function formatKey(vertical) {
  return vertical ? "verticalFormat" : "format"
}

function altFormatKey(vertical) {
  return vertical ? "verticalFormatAlt" : "formatAlt"
}

function defaultFormat(vertical) {
  return (vertical ? VERTICAL_CLOCK_FORMATS : CLOCK_FORMATS)[0]
}

function defaultAltFormat(vertical) {
  return vertical ? DEFAULT_VERTICAL_ALT_FORMAT : DEFAULT_HORIZONTAL_ALT_FORMAT
}

// The configured label is a format string in shell.json, matching Omarchy.
// Older Omashell configs stored a preset index instead, so a number is read
// through the preset list once and written back as a format string.
function formatFromSetting(value, vertical) {
  var presets = clockFormats(vertical)
  if (typeof value === "number") {
    var index = isFinite(value) ? Math.round(value) : -1
    if (index >= 0 && index < presets.length) return presets[index]
    return presets[0]
  }
  var text = value === undefined || value === null ? "" : String(value)
  return text === "" ? presets[0] : text
}

function altFormatFromSetting(value, vertical) {
  if (value === undefined || value === null) return defaultAltFormat(vertical)
  return String(value)
}

// The presets in a fixed order, plus the configured alternate and current
// format when they are something else. The order must not depend on which
// entry is current: cycling writes the result back to shell.json, and a ring
// that reshuffled itself around the current value would bounce between two
// entries instead of walking.
function clockFormatRing(configured, configuredAlt, presets) {
  var ring = []
  var candidates = (presets || []).concat([configuredAlt, configured])
  for (var i = 0; i < candidates.length; i++) {
    var format = String(candidates[i] === undefined || candidates[i] === null ? "" : candidates[i])
    if (format === "" || ring.indexOf(format) !== -1) continue
    ring.push(format)
  }
  return ring.length > 0 ? ring : ["HH:mm"]
}

function nextClockFormat(ring, current) {
  if (!ring || ring.length === 0) return ""
  var index = ring.indexOf(String(current === undefined || current === null ? "" : current))
  return ring[(index + 1) % ring.length]
}

// The settings mutation a right click performs. Keeping it here means the
// key ("format" or "verticalFormat") and the persisted value are testable.
function cycleClockFormat(settings, vertical) {
  var source = settings && typeof settings === "object" ? settings : {}
  var key = formatKey(vertical)
  var current = formatFromSetting(source[key], vertical)
  var alt = altFormatFromSetting(source[altFormatKey(vertical)], vertical)
  var ring = clockFormatRing(current, alt, clockFormats(vertical))
  return {
    key: key,
    current: current,
    next: nextClockFormat(ring, current),
    ring: ring
  }
}

// Qt has no ISO week token, so 'ww' is substituted with a literal before Qt
// formats the rest of the format.
function pad2(value) {
  var n = Number(value)
  return (n < 10 ? "0" : "") + n
}

function isoWeek(year, month, day) {
  var date = new Date(Date.UTC(year, month, day))
  var weekday = date.getUTCDay() || 7
  date.setUTCDate(date.getUTCDate() + 4 - weekday)
  var yearStart = new Date(Date.UTC(date.getUTCFullYear(), 0, 1))
  return Math.ceil(((date.getTime() - yearStart.getTime()) / 86400000 + 1) / 7)
}

function isoWeekLiteral(year, month, day) {
  return pad2(isoWeek(year, month, day))
}

function applyWeek(format, week) {
  return String(format === undefined || format === null ? "" : format).replace(/ww/g, String(week))
}

function displayLines(text) {
  return String(text === undefined || text === null ? "" : text).split("\n")
}

// Milliseconds from nowMs to the next whole step, always in (0, step].
// Counted on the epoch clock: local wall time repeats an hour when daylight
// saving ends, and a whole local minute starts on a whole epoch one.
function msUntilNextTick(nowMs, step) {
  var s = Number(step)
  if (!isFinite(s) || s <= 0) s = 60000
  var now = Number(nowMs)
  if (!isFinite(now)) now = 0
  return s - now % s
}

if (typeof module !== "undefined") {
  module.exports = {
    CLOCK_FORMATS: CLOCK_FORMATS,
    VERTICAL_CLOCK_FORMATS: VERTICAL_CLOCK_FORMATS,
    DEFAULT_HORIZONTAL_ALT_FORMAT: DEFAULT_HORIZONTAL_ALT_FORMAT,
    DEFAULT_VERTICAL_ALT_FORMAT: DEFAULT_VERTICAL_ALT_FORMAT,
    clockNeedsSeconds: clockNeedsSeconds,
    clockFormats: clockFormats,
    formatKey: formatKey,
    altFormatKey: altFormatKey,
    defaultFormat: defaultFormat,
    defaultAltFormat: defaultAltFormat,
    formatFromSetting: formatFromSetting,
    altFormatFromSetting: altFormatFromSetting,
    clockFormatRing: clockFormatRing,
    nextClockFormat: nextClockFormat,
    cycleClockFormat: cycleClockFormat,
    pad2: pad2,
    isoWeek: isoWeek,
    isoWeekLiteral: isoWeekLiteral,
    applyWeek: applyWeek,
    displayLines: displayLines,
    msUntilNextTick: msUntilNextTick
  }
}
