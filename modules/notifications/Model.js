var CRITICAL = 2
var LOW_DURATION = 5000
var NORMAL_DURATION = 8000
var MAX_DURATION = 30000
var MAX_HISTORY = 100
var MAX_SOURCE = 256
var MAX_SUMMARY = 2048
var MAX_BODY = 32768
var MAX_ACTION_LABEL = 256
var MAX_ACTION_ID = 256

var ENTITIES = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ' }

function bounded(value, max) {
  return typeof value === 'string' ? value.slice(0, max) : ''
}

function escapeHtml(text) {
  return String(text || '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
}

function decodeOnce(text) {
  return String(text || '')
    .replace(/&#(\d{1,7});/g, function(whole, digits) {
      var code = parseInt(digits, 10)
      return code > 0 && code < 0x110000 ? String.fromCodePoint(code) : whole
    })
    .replace(/&#x([0-9a-f]{1,6});/gi, function(whole, digits) {
      var code = parseInt(digits, 16)
      return code > 0 && code < 0x110000 ? String.fromCodePoint(code) : whole
    })
    .replace(/&([a-z]+);/gi, function(whole, name) {
      var hit = ENTITIES[String(name).toLowerCase()]
      return hit === undefined ? whole : hit
    })
}

function decodeEntities(text) {
  var out = bounded(text, MAX_BODY)
  for (var i = 0; i < 3; i++) {
    var once = decodeOnce(out)
    if (once === out) break
    out = once
  }
  return out
}

function safeHttpUrl(raw) {
  var text = bounded(raw, 4096)
  if (!/^https?:/i.test(text) || /[\x00-\x20\x7f-\x9f<>"'\\]/.test(text)) return ''
  var match = text.match(/^(https?):\/\/([a-z0-9](?:[a-z0-9.-]*[a-z0-9])?)(?::(\d{1,5}))?([/?#][^]*)?$/i)
  if (!match) return ''
  if (match[3] && (Number(match[3]) < 1 || Number(match[3]) > 65535)) return ''
  return match[1].toLowerCase() + '://' + match[2].toLowerCase() + (match[3] ? ':' + Number(match[3]) : '') + (match[4] || '')
}

function renderBody(body) {
  var text = decodeEntities(body)
  var escaped = escapeHtml(text).replace(/\r?\n/g, '<br/>')
  escaped = escaped.replace(/&lt;(\/?)(b|i|u|s|strong)&gt;/gi, function(whole, slash, tag) {
    return '<' + slash + tag.toLowerCase() + '>'
  })
  escaped = escaped.replace(/&lt;(\/?)em&gt;/gi, '<$1i>')
  escaped = escaped.replace(/&lt;br\s*\/?&gt;/gi, '<br/>')
  escaped = escaped.replace(/&lt;a\s+href=(?:&quot;|")([^"&]+)(?:&quot;|")[^&]*&gt;([^]*?)&lt;\/a&gt;/gi,
    function(whole, href, label) {
      var safe = safeHttpUrl(href)
      return safe ? '<a href="' + escapeHtml(safe) + '">' + label + '</a>' : label
    })
  if (!/<a\b/i.test(escaped)) {
    escaped = escaped.replace(/(https?:\/\/[^\s<]+)/g, function(url) {
      var safe = safeHttpUrl(decodeEntities(url))
      return safe ? '<a href="' + escapeHtml(safe) + '">' + url + '</a>' : url
    })
  }
  return escaped
}

function oneLine(body) {
  return decodeOnce(String(renderBody(body)).replace(/<[^>]+>/g, ' ').replace(/&lt;/g, '<').replace(/&gt;/g, '>').replace(/&amp;/g, '&'))
    .replace(/\s+/g, ' ')
    .trim()
}

function safeImage(value) {
  var text = String(value || '')
  if (/^image:\/\/qsimage\/[0-9]+\/[0-9]+$/.test(text)) return text
  if (text.indexOf('image://icon/') === 0) return ''
  if (/^file:\/\//i.test(text)) {
    if (!/^file:\/\/\//i.test(text) || /[?#]/.test(text)) return ''
    try { text = decodeURIComponent(text.slice(7)) } catch (e) { return '' }
  }
  if (text.length > 1024 || text.charAt(0) !== '/' || /[\x00-\x1f\x7f-\x9f]/.test(text)) return ''
  var parts = text.slice(1).split('/')
  for (var i = 0; i < parts.length; i++) if (!parts[i] || parts[i] === '.' || parts[i] === '..') return ''
  if (/^\/(proc|sys|dev)(\/|$)/.test(text)) return ''
  if (/^\/run(\/|$)/.test(text) && !/^\/run\/user\/[0-9]+\/.+/.test(text)) return ''
  return 'file://' + text.split('/').map(encodeURIComponent).join('/')
}

function codes(summary, body) {
  var text = String(summary || '') + '\n' + String(body || '')
  if (!/\b(code|otp|verification|verify|passcode|pin|2fa|security)\b/i.test(text)) return []
  var out = [], seen = {}, re = /\b(\d{4,8}|[A-Z0-9]{5,8})\b/g, match
  while ((match = re.exec(text)) !== null && out.length < 3) {
    if (/\d/.test(match[1]) && !seen[match[1]]) { seen[match[1]] = true; out.push(match[1]) }
  }
  return out
}

function execArgv(raw) {
  var argv = raw
  if (typeof raw === 'string') { try { argv = JSON.parse(raw) } catch (e) { return [] } }
  if (!argv || typeof argv.length !== 'number' || argv.length < 1 || argv.length > 32) return []
  for (var i = 0; i < argv.length; i++)
    if (typeof argv[i] !== 'string' || argv[i].length > 4096 || argv[i].indexOf('\u0000') >= 0) return []
  return argv[0] && argv[0].charAt(0) !== '-' ? Array.prototype.slice.call(argv) : []
}

function execActions(raw) {
  var data = raw
  if (typeof raw === 'string') { try { data = JSON.parse(raw) } catch (e) { return [] } }
  if (!data || typeof data.length !== 'number') return []
  var out = []
  for (var i = 0; i < data.length && out.length < 3; i++) {
    var item = data[i] || {}, argv = item.argv, label = String(item.label || '').trim().slice(0, 128)
    if (typeof argv === 'string') { try { argv = JSON.parse(argv) } catch (e) { argv = null } }
    if (!label || !argv || typeof argv.length !== 'number' || argv.length < 1 || argv.length > 32) continue
    var valid = true
    for (var j = 0; j < argv.length; j++) if (typeof argv[j] !== 'string' || argv[j].length > 4096 || argv[j].indexOf('\u0000') >= 0) valid = false
    if (valid && argv[0] && argv[0].charAt(0) !== '-') out.push({ label: label, argv: Array.prototype.slice.call(argv) })
  }
  return out
}

function actions(raw) {
  var list = raw && typeof raw.length === 'number' ? raw : []
  var out = []
  for (var i = 0; i < list.length && out.length < 8; i++) {
    var item = list[i] || {}
    var id = bounded(String(item.id === undefined ? item.identifier : item.id), MAX_ACTION_ID).trim()
    var label = bounded(String(item.text === undefined ? item.label : item.text), MAX_ACTION_LABEL).trim()
    if (id === '' || label === '') continue
    out.push({ id: id, text: label })
  }
  return out
}

function snapshot(raw, key, now) {
  var source = raw || {}
  var urgency = Number(source.urgency)
  if (urgency !== 0 && urgency !== 1 && urgency !== 2) urgency = 1
  return {
    key: String(key),
    id: Number(source.id) || 0,
    app: bounded(String(source.app === undefined ? source.appName : source.app), MAX_SOURCE).trim(),
    appIcon: bounded(String(source.appIcon || ''), 1024),
    image: safeImage(source.image),
    summary: bounded(String(source.summary || ''), MAX_SUMMARY).trim(),
    body: bounded(String(source.body || ''), MAX_BODY),
    html: renderBody(source.body),
    urgency: urgency,
    glyph: bounded(String(source.glyph || ''), 16),
    codes: codes(source.summary, source.body),
    execArgv: execArgv(source.execArgv),
    execActions: execActions(source.execActions),
    actions: actions(source.actions),
    timeout: Number(source.timeout) || 0,
    transient: source.transient === true,
    resident: source.resident === true,
    time: Number(now) || Date.now()
  }
}

function isEphemeral(row) {
  if (row && row.transient === true) return true
  var app = String((row && row.app) || '')
  return app === 'notify-send'
}

function bypassesQuiet(row) {
  return String((row && row.app) || '') === 'notify-send' && Number((row && row.urgency) || 0) === CRITICAL
}

function quietReason(row, dnd) {
  if (!dnd) return ''
  if (bypassesQuiet(row)) return ''
  return 'silenced'
}

function durationFor(urgency, requested) {
  if (Number(urgency) === CRITICAL) return 0
  var base = Number(urgency) === 0 ? LOW_DURATION : NORMAL_DURATION
  var ask = Number(requested) > 0 ? Number(requested) : 0
  return Math.min(MAX_DURATION, Math.max(base, ask))
}

function cap(rows, max) {
  var limit = Number(max) > 0 ? Number(max) : MAX_HISTORY
  return rows && typeof rows.length === 'number' ? Array.prototype.slice.call(rows, 0, limit) : []
}

function slug(text) {
  return String(text || '').toLowerCase().replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '')
}

function groupKey(row) {
  var app = String((row && row.app) || '')
  if (app === 'notify-send') return 'toast:' + String((row && row.key) || '')
  return 'app:' + slug(app)
}

function ago(moment, now) {
  var ts = Number(moment)
  var current = Number(now) || Date.now()
  if (!ts) return ''
  var seconds = Math.max(0, (current - ts) / 1000)
  if (seconds < 300) return ''
  if (seconds < 3600) return Math.round(seconds / 60) + 'm'
  var then = new Date(ts)
  var pad = function(value) { return (value < 10 ? '0' : '') + value }
  if (new Date(current).toDateString() === then.toDateString()) return pad(then.getHours()) + ':' + pad(then.getMinutes())
  if (new Date(current - 86400000).toDateString() === then.toDateString()) return 'yesterday'
  return ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][then.getDay()]
}

var PEEK = 10
var SHRINK = 0.035
var VISIBLE = 3
var STACK_FADE = 0.55

function panelLayout(rows, expanded, heights, options) {
  var settings = options || {}
  var gap = Number(settings.gap) > 0 ? Number(settings.gap) : 6
  var deckGap = Number(settings.deckGap) > 0 ? Number(settings.deckGap) : 12
  var heightOf = function(key) {
    var value = heights ? Number(heights[key]) : 0
    return value > 0 ? value : 76
  }
  var order = []
  var decks = {}
  for (var i = 0; i < rows.length; i++) {
    var group = groupKey(rows[i])
    if (!decks[group]) {
      decks[group] = []
      order.push(group)
    }
    decks[group].push(rows[i])
  }
  var placements = {}
  var y = 0
  for (var d = 0; d < order.length; d++) {
    var group2 = order[d]
    var items = decks[group2]
    var top = y
    var frontHeight = heightOf(items[0].key)
    var open = !!expanded && (!settings.openGroup || group2 === settings.openGroup)
    var height = 0
    for (var r = 0; r < items.length; r++) {
      var key = items[r].key
      var drawn = r < VISIBLE
      if (open) {
        height = heightOf(key)
        placements[key] = { y: y, scale: 1, opacity: 1, z: 1000 - r, front: r === 0, hidden: false, height: height }
        y += height + gap
      } else {
        placements[key] = {
          height: frontHeight,
          y: top + r * PEEK,
          scale: Math.max(0.7, 1 - r * SHRINK),
          opacity: r === 0 ? 1 : (drawn ? (r === VISIBLE - 1 ? STACK_FADE : 0.85) : 0),
          z: 1000 - r,
          front: r === 0,
          hidden: !drawn
        }
      }
    }
    if (!open) y = top + frontHeight + Math.min(items.length - 1, VISIBLE - 1) * PEEK
    else y -= gap
    if (d < order.length - 1) y += deckGap
  }
  return { placements: placements, height: Math.max(0, y) }
}

function entry(row, reason, now) {
  return {
    key: String(row.key),
    app: row.app,
    appIcon: row.appIcon,
    summary: row.summary,
    body: row.body,
    html: row.html,
    urgency: row.urgency,
    time: Number(now) || Date.now(),
    reason: String(reason || '')
  }
}

function validEntry(value) {
  if (!value || typeof value !== 'object') return null
  var key = bounded(String(value.key || ''), 64).trim()
  if (key === '') return null
  return {
    key: key,
    app: bounded(String(value.app || ''), MAX_SOURCE),
    appIcon: bounded(String(value.appIcon || ''), 1024),
    summary: bounded(String(value.summary || ''), MAX_SUMMARY),
    body: bounded(String(value.body || ''), MAX_BODY),
    html: bounded(String(value.html || ''), MAX_BODY * 4),
    urgency: [0, 1, 2].indexOf(Number(value.urgency)) >= 0 ? Number(value.urgency) : 1,
    time: Number(value.time) || Date.now(),
    reason: bounded(String(value.reason || ''), 32)
  }
}

function parseState(text) {
  var empty = { dnd: false, history: [] }
  try {
    var data = JSON.parse(String(text || ''))
    if (!data || typeof data !== 'object') return empty
    var history = []
    var list = Array.isArray(data.history) ? data.history : []
    for (var i = 0; i < list.length; i++) {
      var row = validEntry(list[i])
      if (row) history.push(row)
    }
    return { dnd: data.dnd === true, history: cap(history, MAX_HISTORY) }
  } catch (e) {
    return empty
  }
}

function serialise(state) {
  var data = state || {}
  var rows = []
  var list = Array.isArray(data.history) ? data.history : []
  for (var i = 0; i < list.length && rows.length < MAX_HISTORY; i++) {
    var row = validEntry(list[i])
    if (row) rows.push(row)
  }
  return JSON.stringify({ dnd: data.dnd === true, history: rows })
}

if (typeof module !== 'undefined') {
  module.exports = {
    CRITICAL: CRITICAL, MAX_HISTORY: MAX_HISTORY, LOW_DURATION: LOW_DURATION,
    NORMAL_DURATION: NORMAL_DURATION, MAX_DURATION: MAX_DURATION,
    bounded: bounded, escapeHtml: escapeHtml, decodeEntities: decodeEntities,
    safeHttpUrl: safeHttpUrl, renderBody: renderBody, oneLine: oneLine,
    actions: actions, safeImage: safeImage, codes: codes, execArgv: execArgv, execActions: execActions,
    snapshot: snapshot, isEphemeral: isEphemeral,
    bypassesQuiet: bypassesQuiet, quietReason: quietReason, durationFor: durationFor,
    cap: cap, slug: slug, groupKey: groupKey, ago: ago,
    panelLayout: panelLayout, PEEK: PEEK, VISIBLE: VISIBLE,
    entry: entry, validEntry: validEntry, parseState: parseState, serialise: serialise
  }
}
