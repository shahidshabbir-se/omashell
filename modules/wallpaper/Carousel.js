function wrap(index, count) {
  return count ? ((index % count) + count) % count : 0
}

function geometry(width, height, outputAspect) {
  const aspect = outputAspect || width / Math.max(1, height)
  const centerWidth = Math.max(1, Math.min(960, width * 0.72, height * 0.60 * aspect))
  const centerHeight = centerWidth / Math.max(aspect, 0.01)
  const sliceWidth = Math.max(20, Math.min(115, centerWidth * 0.14))
  const step = sliceWidth * 0.72
  const sideRoom = (width - centerWidth) / 2 - 4
  const radius = Math.max(0, Math.min(5, Math.floor((sideRoom - sliceWidth) / step) + 1))
  return {centerWidth, centerHeight, sliceWidth, step, radius}
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
  if (offset > 0) return left + layout.centerWidth + (offset - 1) * layout.step
  return left - layout.sliceWidth + (offset + 1) * layout.step
}

function contains(x, y, width, height, bevel) {
  if (y < 0 || y > height || height <= 0) return false
  const left = bevel * (1 - y / height)
  return x >= left && x <= left + width - bevel
}

if (typeof module !== 'undefined') module.exports = {wrap, geometry, windowFor, sync, xFor, contains}
