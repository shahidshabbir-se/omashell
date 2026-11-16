// A workspace button keeps the bar's thickness across the bar. Along the bar
// it is 20px wide horizontally, and as long as the bar is thick vertically:
// the reference bar draws vertical workspaces as full-size square rows rather
// than cramped 20px rows.
var SLOT_LENGTH = 20
var HORIZONTAL_SPACING = 1
var VERTICAL_SPACING = 2
var HORIZONTAL_TRAILING_GAP = 1.5
var GUEST_GAP = 6

function slotMetrics(vertical, barSize) {
  return {
    width: vertical ? Number(barSize) : SLOT_LENGTH,
    height: Number(barSize),
    spacing: vertical ? VERTICAL_SPACING : HORIZONTAL_SPACING,
    trailingGap: vertical ? 0 : HORIZONTAL_TRAILING_GAP
  }
}

function focusDispatchArgs(workspaceId) {
  var id = Number(workspaceId)
  if (!Number.isInteger(id) || id < 1) return []
  return ['dispatch', 'hl.dsp.focus({ workspace = "' + id + '" })']
}

// The workspace a wheel notch lands on. A positive notch is a wheel-up, which
// walks toward the start of the bar; a negative one walks toward its end.
// Both axes use the same rule because vertical bars read top to bottom.
function scrollTarget(ids, activeId, steps) {
  var list = Array.isArray(ids) ? ids : []
  var index = list.indexOf(Number(activeId))
  if (index === -1) return null

  var count = Number(steps)
  if (!isFinite(count)) count = 0
  count = count < 0 ? Math.ceil(count) : Math.floor(count)
  return list[Math.max(0, Math.min(list.length - 1, index - count))]
}

if (typeof module !== 'undefined') {
  module.exports = {
    SLOT_LENGTH: SLOT_LENGTH,
    HORIZONTAL_SPACING: HORIZONTAL_SPACING,
    VERTICAL_SPACING: VERTICAL_SPACING,
    HORIZONTAL_TRAILING_GAP: HORIZONTAL_TRAILING_GAP,
    GUEST_GAP: GUEST_GAP,
    slotMetrics: slotMetrics,
    focusDispatchArgs: focusDispatchArgs,
    scrollTarget: scrollTarget
  }
}
