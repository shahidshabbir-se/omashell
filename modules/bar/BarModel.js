var sectionNames = ['left', 'centerBegin', 'center', 'centerEnd', 'right']
var allowedPositions = ['top', 'bottom', 'left', 'right']

function isObject(value) {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
}

function clone(value) {
  return JSON.parse(JSON.stringify(value))
}

function entryId(entry) {
  if (typeof entry === 'string') return entry
  return isObject(entry) && typeof entry.id === 'string' ? entry.id : ''
}

function configSections(config, defaults) {
  var bar = isObject(config && config.bar) ? config.bar : {}
  var layout = isObject(bar.layout) ? bar.layout : bar
  var fallback = defaults || {}
  var out = {}
  sectionNames.forEach(function(section) {
    var entries = layout[section]
    if (!Array.isArray(entries)) entries = fallback[section]
    out[section] = Array.isArray(entries) ? entries.slice() : []
  })
  // Upgrade the original unversioned default layout without changing custom
  // or versioned layouts, or duplicating music placed in another section.
  var oldRight = ['bluetooth', 'network', 'audio', 'power']
  var hasMusic = sectionNames.some(function(section) {
    return out[section].some(function(entry) { return entryId(entry) === 'music' })
  })
  if (config && config.version === undefined && !hasMusic &&
      Array.isArray(layout.right) && Array.isArray(fallback.right) && fallback.right.indexOf('music') >= 0 &&
      out.right.length === oldRight.length && oldRight.every(function(id, i) { return out.right[i] === id }))
    out.right.unshift('music')
  return out
}

function normalizePosition(value) {
  var position = String(value || '')
  return allowedPositions.indexOf(position) >= 0 ? position : 'top'
}

function normalizeConfig(config, defaults) {
  var next = isObject(config) ? clone(config) : {}
  if (!isObject(next.bar)) next.bar = {}
  var legacyLayout = isObject(next.bar.layout) ? next.bar.layout : next.bar
  var sections = configSections(next, defaults)
  sectionNames.forEach(function(section) { next.bar[section] = sections[section] })
  if (legacyLayout !== next.bar) delete next.bar.layout
  next.bar.position = normalizePosition(next.bar.position)
  if (next.version === undefined) next.version = 1
  return next
}

function sectionFor(config, section) {
  if (!config || !config[section]) return []
  return config[section]
}

function moveWidget(sections, from, to) {
  if (!sections || !from || !to || sectionNames.indexOf(from.section) < 0 || sectionNames.indexOf(to.section) < 0) return false
  var source = sectionFor(sections, from.section)
  var target = sectionFor(sections, to.section)
  var fromIndex = Number(from.index)
  var toIndex = Number(to.index)
  if (!Number.isInteger(fromIndex) || fromIndex < 0 || fromIndex >= source.length) return false
  if (!Number.isInteger(toIndex) || toIndex < 0 || toIndex > target.length) return false
  if (source === target && (fromIndex === toIndex || fromIndex + 1 === toIndex)) return false
  var entry = source.splice(fromIndex, 1)[0]
  if (source === target && fromIndex < toIndex) toIndex--
  target.splice(toIndex, 0, entry)
  return true
}

function removeWidget(sections, section, index) {
  if (!sections || sectionNames.indexOf(section) < 0) return null
  var list = sectionFor(sections, section)
  var at = Number(index)
  if (!Number.isInteger(at) || at < 0 || at >= list.length) return null
  return list.splice(at, 1)[0]
}

function addWidget(sections, section, entry, index) {
  if (!sections || sectionNames.indexOf(section) < 0) return false
  var id = entryId(entry)
  if (!id) return false
  for (var i = 0; i < sectionNames.length; i++) {
    if (sectionFor(sections, sectionNames[i]).some(function(item) { return entryId(item) === id })) return false
  }
  var list = sectionFor(sections, section)
  var at = index === undefined ? list.length : Number(index)
  if (!Number.isInteger(at) || at < 0 || at > list.length) return false
  list.splice(at, 0, entry)
  return true
}

function setWidgetSetting(sections, id, name, value) {
  if (!sections || !id || !name) return false
  for (var i = 0; i < sectionNames.length; i++) {
    var list = sectionFor(sections, sectionNames[i])
    for (var j = 0; j < list.length; j++) {
      if (entryId(list[j]) !== id) continue
      var entry = isObject(list[j]) ? clone(list[j]) : { id: id }
      if (entry[name] === value) return false
      entry[name] = value
      list[j] = entry
      return true
    }
  }
  return false
}

function entryIndexById(entries, id) {
  var key = String(id || '')
  if (!key || !Array.isArray(entries)) return -1
  for (var i = 0; i < entries.length; i++) {
    if (entryId(entries[i]) === key) return i
  }
  return -1
}

// The widget ids each section shows, in order, as a stringable snapshot. A
// drag holds this from the moment it starts: an external layout write that
// changes it aborts the drag instead of landing on a layout nobody saw.
function layoutKeys(sections) {
  var out = {}
  sectionNames.forEach(function(section) {
    var list = Array.isArray(sections && sections[section]) ? sections[section] : []
    out[section] = list.map(entryId)
  })
  return out
}

// A drop beside a widget, or at an end of a section: { region, key, after }.
// With a key, after=false inserts before it and after=true after it. Without
// a key, after=true appends to the section and after=false prepends.
function targetIndexById(entries, target) {
  if (!Array.isArray(entries) || !target) return -1
  if (target.key) {
    var at = entryIndexById(entries, target.key)
    if (at < 0) return -1
    return at + (target.after ? 1 : 0)
  }
  return target.after ? entries.length : 0
}

// Moves the first entry for `from.id` in `from.region` to a target in
// `to.region` (targetIndexById). Identity rather than a draw index keeps a
// widget that hid itself, or an entry the bar doesn't draw, from shifting the
// move to a neighbour. Entries are preserved as they are.
function moveWidgetById(sections, from, to) {
  if (!sections || !from || !to) return false
  if (sectionNames.indexOf(from.region) < 0 || sectionNames.indexOf(to.region) < 0) return false
  var source = sectionFor(sections, from.region)
  var target = sectionFor(sections, to.region)
  var fromIndex = entryIndexById(source, from.id)
  if (fromIndex < 0) return false
  var toIndex = targetIndexById(target, to)
  if (toIndex < 0) return false
  var same = source === target
  if (same && (toIndex === fromIndex || toIndex === fromIndex + 1)) return false
  var entry = source.splice(fromIndex, 1)[0]
  if (same && fromIndex < toIndex) toIndex--
  target.splice(toIndex, 0, entry)
  return true
}

// Drops the first entry for `id` from a section. Returns its entry, or null
// when the id is not there. A hidden or undrawn entry ahead of the widget
// cannot make this remove the wrong neighbour.
function removeWidgetById(sections, section, id) {
  if (!sections || sectionNames.indexOf(section) < 0) return null
  var list = sectionFor(sections, section)
  var at = entryIndexById(list, id)
  if (at < 0) return null
  return list.splice(at, 1)[0]
}

// The edge of a visible widget nearest a pointer along the bar. Candidates
// are { key, region, x, y, width, height }; the result is { region, key,
// after, distance }. Empty space between widgets belongs to their nearest
// edges rather than to a fixed section box.
function nearestEdge(candidates, axis, vertical) {
  var rows = Array.isArray(candidates) ? candidates : []
  if (!isFinite(axis)) return null
  var best = null
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    if (!row || !row.key) continue
    var start = Number(vertical ? row.y : row.x)
    var size = Number(vertical ? row.height : row.width)
    if (!isFinite(start) || !isFinite(size) || size < 0) continue
    var beforeDistance = Math.abs(axis - start)
    var afterDistance = Math.abs(axis - (start + size))
    var after = afterDistance < beforeDistance
    var distance = after ? afterDistance : beforeDistance
    if (!best || distance < best.distance)
      best = { region: row.region, key: row.key, after: after, distance: distance }
  }
  return best
}

function nearestDropTarget(candidates, point, vertical) {
  return nearestEdge(candidates, Number(vertical ? point && point.y : point && point.x), vertical)
}

// A drop over the room the dragged widget (`source`) still holds puts it
// back there. That keeps the drag from jumping to a neighbour before the
// pointer has left its own slot.
function ownRoomTarget(candidates, axis, vertical, source) {
  if (!source || !source.key) return null
  var rows = Array.isArray(candidates) ? candidates : []
  for (var i = 0; i < rows.length; i++) {
    var row = rows[i]
    if (!row || row.key !== source.key) continue
    var start = Number(vertical ? row.y : row.x)
    var size = Number(vertical ? row.height : row.width)
    if (isFinite(start) && isFinite(size) && size > 0 && axis >= start && axis <= start + size)
      return { region: row.region, key: row.key, after: false }
  }
  return null
}

// The stretch of the bar over which a drop lands in the center box: its
// length along the bar, or at least `reach` (the bar's thickness), centered
// on it, so an empty center box can still be hit.
function centerDropZone(box, reach, vertical) {
  if (!box) return null
  var length = Number(vertical ? box.height : box.width)
  var grown = Math.max(length, Number(reach) || 0)
  var shift = (length - grown) / 2
  return vertical
    ? { x: box.x, y: box.y + shift, width: box.width, height: grown }
    : { x: box.x + shift, y: box.y, width: grown, height: box.height }
}

// A drop in the center box targets the center widgets, or the box itself when
// it holds none. Off the box, the nearest non-center widget wins, with the
// box's outer edges standing for an empty centerBegin or centerEnd.
function centerDropTarget(candidates, zone, point, vertical, source) {
  var rows = Array.isArray(candidates) ? candidates : []
  if (!zone) return nearestDropTarget(rows, point, vertical)
  var axis = Number(vertical ? point && point.y : point && point.x)
  var start = Number(vertical ? zone.y : zone.x)
  var end = start + Number(vertical ? zone.height : zone.width)
  if (!isFinite(axis) || !isFinite(start) || !isFinite(end)) return null

  var own = ownRoomTarget(rows, axis, vertical, source)
  if (own) return own

  if (axis >= start && axis <= end) {
    var inside = nearestEdge(rows.filter(function(row) { return row && row.region === 'center' }), axis, vertical)
    return inside || { region: 'center', after: true }
  }

  var outside = nearestEdge(rows.filter(function(row) { return row && row.region !== 'center' }), axis, vertical)
  var edge = Math.abs(axis - start) <= Math.abs(axis - end)
    ? { region: 'centerBegin', after: true, distance: Math.abs(axis - start) }
    : { region: 'centerEnd', after: false, distance: Math.abs(axis - end) }
  return outside && outside.distance <= edge.distance ? outside : edge
}

// The visible place a drop would open room at, and whether that is the
// dragged widget's own place. Candidates are visible widgets with
// { key, region }. A target beside a key is before/after it; no key means
// the section start or end. Either side of the dragged widget is home, so
// the room never jumps across it while the pointer is still on it.
function dropRoom(drop, source, candidates) {
  var rows = Array.isArray(candidates) ? candidates : []
  if (!source || !source.key || !source.region) return null
  var sourceRows = rows.filter(function(row) {
    return row && row.region === source.region
  })
  var sourcePlace = -1
  for (var s = 0; s < sourceRows.length; s++) {
    if (sourceRows[s].key === source.key) { sourcePlace = s; break }
  }
  if (sourcePlace < 0) return null
  var home = { region: source.region, index: sourcePlace, home: true }
  if (!drop) return home

  var targetRows = rows.filter(function(row) {
    return row && row.region === drop.region
  })
  var index = drop.after ? targetRows.length : 0
  if (drop.key) {
    var at = -1
    for (var i = 0; i < targetRows.length; i++) {
      if (targetRows[i].key === drop.key) { at = i; break }
    }
    if (at < 0) return home
    index = at + (drop.after ? 1 : 0)
  }

  if (drop.region === source.region && (index === sourcePlace || index === sourcePlace + 1))
    return home
  return { region: drop.region, index: index, home: false }
}

// One frame of the room moving: every place but the target gives up `step`
// of the whole room, and the target holds what is left. Keys are
// "region:place". A place that has given up all of it is dropped.
function fadeShares(shares, target, step) {
  var next = {}
  var others = 0
  var amount = Number(step)
  if (!isFinite(amount) || amount < 0) amount = 0
  for (var key in shares || {}) {
    if (key === target) continue
    var share = Number(shares[key]) - amount
    if (share > 0) {
      next[key] = share
      others += share
    }
  }
  if (target) next[target] = Math.max(0, 1 - others)
  return next
}

// The length each place takes of a room `extent` long, in whole pixels: the
// rounded length shared out by largest remainder so the places add up
// exactly. A layout places its items on whole pixels.
function roomLengths(extent, shares) {
  var totalExtent = Number(extent)
  if (!isFinite(totalExtent) || totalExtent <= 0) return {}
  var places = Object.keys(shares || {})
  var raw = places.map(function(place) { return totalExtent * Number(shares[place]) })
  var lengths = {}
  var total = Math.round(raw.reduce(function(sum, value) { return sum + value }, 0))
  var given = 0
  for (var i = 0; i < places.length; i++) {
    lengths[places[i]] = Math.floor(raw[i])
    given += lengths[places[i]]
  }
  var byRemainder = places.map(function(place, at) { return at })
  byRemainder.sort(function(a, b) {
    return (raw[b] - Math.floor(raw[b])) - (raw[a] - Math.floor(raw[a]))
  })
  for (var r = 0; r < total - given; r++) lengths[places[byRemainder[r]]]++
  return lengths
}

function centerGeometry(barLength, beginLength, centerLength, endLength) {
  var centerStart = (barLength - centerLength) / 2
  return {
    center: centerStart,
    begin: centerStart - beginLength,
    end: centerStart + centerLength
  }
}

function sectionAt(point, geometry) {
  if (!geometry) return 'center'
  if (point < geometry.centerStart) return point < geometry.beginStart ? 'left' : 'centerBegin'
  if (point < geometry.centerEnd) return 'center'
  if (point < geometry.endEnd) return 'centerEnd'
  return 'right'
}

function revealed(hovered, alwaysShow) {
  return hovered === true || alwaysShow === true
}

function dragDistanceOutside(point, width, height) {
  var x = Number(point && point.x)
  var y = Number(point && point.y)
  var w = Number(width)
  var h = Number(height)
  if (!isFinite(x) || !isFinite(y) || !isFinite(w) || !isFinite(h)) return 0
  var dx = x < 0 ? -x : (x > w ? x - w : 0)
  var dy = y < 0 ? -y : (y > h ? y - h : 0)
  return Math.sqrt(dx * dx + dy * dy)
}

if (typeof module !== 'undefined') {
  module.exports = {
    sectionNames: sectionNames,
    allowedPositions: allowedPositions,
    entryId: entryId,
    configSections: configSections,
    normalizePosition: normalizePosition,
    normalizeConfig: normalizeConfig,
    moveWidget: moveWidget,
    removeWidget: removeWidget,
    moveWidgetById: moveWidgetById,
    removeWidgetById: removeWidgetById,
    layoutKeys: layoutKeys,
    addWidget: addWidget,
    setWidgetSetting: setWidgetSetting,
    nearestEdge: nearestEdge,
    nearestDropTarget: nearestDropTarget,
    centerDropZone: centerDropZone,
    centerDropTarget: centerDropTarget,
    dropRoom: dropRoom,
    fadeShares: fadeShares,
    roomLengths: roomLengths,
    centerGeometry: centerGeometry,
    sectionAt: sectionAt,
    revealed: revealed,
    dragDistanceOutside: dragDistanceOutside
  }
}
