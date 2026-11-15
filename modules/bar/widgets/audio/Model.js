function clamp(value, maximum) {
  var n = Number(value)
  return isFinite(n) ? Math.max(0, Math.min(maximum, n)) : 0
}

function snapshot(nodes, accept) {
  var rows = []
  for (var i = 0; i < nodes.length; i++) {
    var node = nodes[i]
    if (node && node.id !== undefined && node.id !== null && accept(node))
      rows.push({ id: node.id, name: String(node.name || '') })
  }
  return rows
}

function outputAvailability(raw) {
  var result = {}
  var devices
  try { devices = JSON.parse(raw) } catch (e) { return result }
  if (!Array.isArray(devices)) return result
  for (var i = 0; i < devices.length; i++) {
    var d = devices[i]
    if (!d || !d.name || !Array.isArray(d.ports) || d.ports.length === 0) continue
    result[d.name] = d.ports.some(function(port) {
      var state = String(port.availability || port.available || '').toLowerCase()
      return state !== 'no' && state !== 'not available' && state !== 'unavailable'
    })
  }
  return result
}

function findNode(nodes, row) {
  if (!row) return null
  for (var i = 0; i < nodes.length; i++)
    if (nodes[i] && nodes[i].id === row.id && String(nodes[i].name || '') === row.name) return nodes[i]
  return null
}

function label(node) {
  if (!node) return 'Unknown'
  var props = node.ready && node.properties ? node.properties : {}
  var value = node.nickname || props['node.nick'] || props['device.profile.description'] || node.description || props['node.description'] || node.name || 'Unknown'
  return String(value).replace(/^sof-soundwire\s+/i, '').replace(/^built-?in audio\s+/i, '').replace(/\s+(input|output)$/i, '').replace(/\bMicrophones\b/g, 'Microphone').trim()
}

function streamLabel(node) {
  if (!node) return 'Stream'
  var props = node.ready && node.properties ? node.properties : {}
  return String(props['application.name'] || node.description || props['media.name'] || node.name || 'Stream')
}

function headphones(node) {
  if (!node) return false
  var props = node.ready && node.properties ? node.properties : {}
  return /headphones?|headsets?|earbuds?|earphones?|airpods?/i.test([node.name, node.description, node.nickname, props['device.icon-name'], props['node.nick']].join(' '))
}

function deviceIcon(node, input) {
  if (headphones(node)) return '󰋋'
  var props = node && node.ready && node.properties ? node.properties : {}
  var name = node ? [node.name, node.description, props['device.icon-name']].join(' ') : ''
  if (/bluetooth|bluez/i.test(name)) return '󰂯'
  if (input) return /camera|webcam/i.test(name) ? '󰄀' : '󰍬'
  return /hdmi|display/i.test(name) ? '󰍹' : '󰓃'
}

function volumeIcon(node, volume, muted) {
  if (!node) return ''
  if (headphones(node)) return '󰋋'
  if (muted || volume <= 0) return ''
  return volume >= 0.67 ? '' : volume >= 0.34 ? '' : ''
}

function volumeName(volume, muted) {
  if (muted) return 'Muted'
  if (volume <= 0) return 'Silent'
  if (volume >= 0.75) return 'Loud'
  if (volume >= 0.35) return 'Listening'
  return 'Quiet'
}

if (typeof module !== 'undefined') module.exports = { clamp, snapshot, outputAvailability, findNode, label, streamLabel, headphones, deviceIcon, volumeIcon, volumeName }
