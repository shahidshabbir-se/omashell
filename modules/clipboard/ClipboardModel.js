// CSS hex uses RGBA order for eight digits, unlike Qt's color strings.
function colorChannels(text) {
  var match = /^#([\da-f]{3}|[\da-f]{4}|[\da-f]{6}|[\da-f]{8})$/i.exec(text.trim())
  if (!match) return null
  var hex = match[1]
  if (hex.length < 5) hex = hex.replace(/./g, function(digit) { return digit + digit })
  if (hex.length === 6) hex += 'ff'
  return hex.match(/../g).map(function(byte) { return parseInt(byte, 16) / 255 })
}

function classify(entry) {
  var rgba = entry.mime.startsWith('text/plain') ? colorChannels(entry.preview) : null
  var type = entry.mime === 'image/png' ? 'images'
    : entry.mime === 'text/uri-list' ? 'files'
    : rgba ? 'colors'
    : /^https?:\/\/[^\s/?#]+[^\s]*$/i.test(entry.preview.trim()) ? 'links'
    : 'text'
  return { id: entry.id, mime: entry.mime, preview: entry.preview, type: type, rgba: rgba }
}

function filter(entries, type, query) {
  var needle = query.trim().toLowerCase()
  return entries.filter(function(entry) {
    return (type === 'all' || type === entry.type) && entry.preview.toLowerCase().includes(needle)
  })
}

if (typeof module !== 'undefined') module.exports = { colorChannels, classify, filter }
