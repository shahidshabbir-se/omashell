// All positions are in Hyprland's logical coordinate space, not mode pixels.
function rect(output) {
  const turned = (output.transform || 0) % 2 === 1
  return {
    x: output.x, y: output.y,
    width: Math.round((turned ? output.height : output.width) / output.scale),
    height: Math.round((turned ? output.width : output.height) / output.scale)
  }
}

function overlaps(a, b) {
  return a.x < b.x + b.width && b.x < a.x + a.width
    && a.y < b.y + b.height && b.y < a.y + a.height
}

function bounds(rectangles) {
  if (!rectangles.length) return { x: 0, y: 0, width: 1, height: 1 }
  const x = Math.min(...rectangles.map(r => r.x))
  const y = Math.min(...rectangles.map(r => r.y))
  return {
    x, y,
    width: Math.max(...rectangles.map(r => r.x + r.width)) - x,
    height: Math.max(...rectangles.map(r => r.y + r.height)) - y
  }
}

// Snap flush edges where the screens touch, optionally lining up their ends.
// Reject collisions against every screen, not only the snap target.
function place(moving, others, x, y, distance) {
  const target = { x: Math.round(x), y: Math.round(y), width: moving.width, height: moving.height }
  const candidates = []
  function add(x, y) {
    const candidate = { ...target, x, y }
    const cost = Math.hypot(x - target.x, y - target.y)
    if (cost <= distance && !others.some(other => overlaps(candidate, other))) {
      candidates.push({ x, y, cost })
    }
  }
  for (const other of others) {
    for (const left of [other.x - moving.width, other.x + other.width]) {
      const minY = other.y - moving.height + 1
      const maxY = other.y + other.height - 1
      add(left, Math.max(minY, Math.min(maxY, target.y)))
      add(left, other.y)
      add(left, other.y + other.height - moving.height)
    }
    for (const top of [other.y - moving.height, other.y + other.height]) {
      const minX = other.x - moving.width + 1
      const maxX = other.x + other.width - 1
      add(Math.max(minX, Math.min(maxX, target.x)), top)
      add(other.x, top)
      add(other.x + other.width - moving.width, top)
    }
  }
  candidates.sort((a, b) => a.cost - b.cost)
  if (candidates.length) return { x: candidates[0].x, y: candidates[0].y }
  if (others.some(other => overlaps(target, other))) return null
  return { x: target.x, y: target.y }
}

if (typeof module !== 'undefined') module.exports = { rect, overlaps, bounds, place }
