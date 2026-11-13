.pragma library

var DEG = Math.PI / 180
var AXIAL_TILT = 23.44

function mix(from, to, t) {
  return Qt.rgba(
    from.r + (to.r - from.r) * t,
    from.g + (to.g - from.g) * t,
    from.b + (to.b - from.b) * t,
    1)
}

function alpha(color, a) {
  return Qt.rgba(color.r, color.g, color.b, a)
}

function project(lat, lon, spin, viewLat, r) {
  var phi = lat * DEG
  var lam = (lon - spin) * DEG
  var p0 = viewLat * DEG
  var cosc = Math.sin(p0) * Math.sin(phi) + Math.cos(p0) * Math.cos(phi) * Math.cos(lam)
  return {
    x: r * Math.cos(phi) * Math.sin(lam),
    y: -r * (Math.cos(p0) * Math.sin(phi) - Math.sin(p0) * Math.cos(phi) * Math.cos(lam)),
    visible: cosc > 0,
    cosc: cosc
  }
}

function limbCrossing(a, b, spin, viewLat, r) {
  if (Math.abs(b[1] - a[1]) > 180) return null
  var lo = 0
  var hi = 1
  for (var i = 0; i < 8; i++) {
    var m = (lo + hi) / 2
    var p = project(a[0] + (b[0] - a[0]) * m, a[1] + (b[1] - a[1]) * m, spin, viewLat, r)
    if (p.visible) lo = m
    else hi = m
  }
  return project(a[0] + (b[0] - a[0]) * lo, a[1] + (b[1] - a[1]) * lo, spin, viewLat, r)
}

function visibleSegments(pts, spin, viewLat, r) {
  var out = []
  var run = []
  var prev = null
  var prevVis = false

  function flush() {
    if (run.length > 1) out.push(run)
    run = []
  }

  for (var i = 0; i < pts.length; i++) {
    var p = project(pts[i][0], pts[i][1], spin, viewLat, r)
    if (p.visible) {
      if (run.length === 0 && prev !== null && !prevVis) {
        var enter = limbCrossing(pts[i], prev, spin, viewLat, r)
        if (enter) run.push(enter)
      }
      run.push(p)
    } else {
      if (run.length > 0 && prev !== null) {
        var exit = limbCrossing(prev, pts[i], spin, viewLat, r)
        if (exit) run.push(exit)
      }
      flush()
    }
    prev = pts[i]
    prevVis = p.visible
  }

  flush()
  return out
}

function clipRingToDisc(ring, spin, viewLat, r) {
  var pts = []
  for (var k = 0; k < ring.length; k += 2) pts.push([ring[k + 1], ring[k]])
  var out = []

  for (var i = 0; i < pts.length; i++) {
    var A = pts[i]
    var B = pts[(i + 1) % pts.length]
    var pa = project(A[0], A[1], spin, viewLat, r)
    var pb = project(B[0], B[1], spin, viewLat, r)

    if (pa.visible && pb.visible) out.push({ p: pb, limb: false })
    else if (pa.visible) {
      var ex = limbCrossing(A, B, spin, viewLat, r)
      if (ex) out.push({ p: ex, limb: true })
    } else if (pb.visible) {
      var en = limbCrossing(B, A, spin, viewLat, r)
      if (en) out.push({ p: en, limb: true })
      out.push({ p: pb, limb: false })
    }
  }

  if (out.length < 3) return []

  var res = []
  for (var j = 0; j < out.length; j++) {
    res.push(out[j].p)
    var nx = out[(j + 1) % out.length]
    if (!out[j].limb || !nx.limb) continue

    var a0 = Math.atan2(out[j].p.y, out[j].p.x)
    var a1 = Math.atan2(nx.p.y, nx.p.x)
    var d = a1 - a0
    while (d > Math.PI) d -= 2 * Math.PI
    while (d < -Math.PI) d += 2 * Math.PI
    var steps = Math.max(1, Math.round(Math.abs(d) / 0.15))
    for (var t = 1; t < steps; t++) {
      var a = a0 + d * t / steps
      res.push({ x: r * Math.cos(a), y: r * Math.sin(a) })
    }
  }

  return res
}
