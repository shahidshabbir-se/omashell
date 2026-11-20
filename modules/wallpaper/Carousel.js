function wrap(index, count) {
  return count ? ((index % count) + count) % count : 0
}

// Match the quattro picker proportions. Viewport size only constrains the
// canvas on small displays; it does not determine the crop's aspect ratio.
function geometry(width, height) {
  const scale = Math.max(1 / 768, Math.min(1, width * 0.84 / 768, (height - 92) / 475))
  const centerWidth = 768 * scale
  const centerHeight = 475 * scale
  const sliceWidth = 108 * scale
  const sliceHeight = 432 * scale
  const overlap = 30 * scale
  const bevel = 28 * scale
  const step = sliceWidth - overlap
  const sideRoom = (width - centerWidth) / 2 - 4
  const radius = Math.max(0, Math.min(6, Math.floor(sideRoom / step)))
  return {centerWidth, centerHeight, sliceWidth, sliceHeight, overlap, bevel, step, radius}
}

function windowFor(selected, count, radius) {
  if (!count) return []
  const left = Math.min(radius, Math.floor((count - 1) / 2))
  const right = Math.min(radius, Math.floor(count / 2))
  const rows = [{imageIndex: selected, offset: 0}]
  // Priority order: center first, then the closest neighbors.
  for (let distance = 1; distance <= Math.max(left, right); distance++) {
    if (distance <= right) rows.push({imageIndex: wrap(selected + distance, count), offset: distance})
    if (distance <= left) rows.push({imageIndex: wrap(selected - distance, count), offset: -distance})
  }
  return rows
}

function sync(model, rows) {
  const desired = new Map(rows.map(row => [row.imageIndex, row.offset]))
  // Updating in place preserves QML Image instances for the overlapping rows.
  for (let i = model.count - 1; i >= 0; i--) {
    const row = model.get(i)
    if (!desired.has(row.imageIndex)) model.remove(i)
    else {
      const offset = desired.get(row.imageIndex)
      if (row.offset !== offset) model.setProperty(i, "offset", offset)
      desired.delete(row.imageIndex)
    }
  }
  for (const [imageIndex, offset] of desired) model.append({imageIndex, offset})
}

function xFor(width, layout, offset) {
  const left = (width - layout.centerWidth) / 2
  if (!offset) return left
  if (offset > 0) return left + layout.centerWidth - layout.overlap + (offset - 1) * layout.step
  return left + offset * layout.step
}

function contains(x, y, width, height, bevel) {
  if (y < 0 || y > height || height <= 0) return false
  const left = bevel * (1 - y / height)
  return x >= left && x <= left + width - bevel
}

if (typeof module !== 'undefined') module.exports = {wrap, geometry, windowFor, sync, xFor, contains}
