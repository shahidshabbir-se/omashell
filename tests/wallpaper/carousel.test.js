const assert = require('node:assert/strict')
const { geometry, windowFor, wrap, sync, xFor, contains } = require('../../modules/wallpaper/Carousel.js')

for (const [width, height] of [[2752, 1152], [1920, 1080], [1280, 800], [900, 1600], [640, 480]]) {
  const deckWidth = Math.min(1840, width - 48)
  const layout = geometry(deckWidth, height, width / height)
  assert.ok(Math.abs(layout.centerWidth / layout.centerHeight - width / height) < 1e-9)
  const rows = windowFor(0, 101, layout.radius)
  assert.ok(rows.length <= 11)
  for (const {offset} of rows) {
    const x = xFor(deckWidth, layout, offset)
    const end = x + (offset ? layout.sliceWidth : layout.centerWidth)
    assert.ok(x >= 4 && end <= deckWidth - 4, `Tile ${offset} clips at ${width}×${height}`)
  }
}

assert.equal(wrap(-1, 101), 100)
assert.equal(wrap(102, 101), 1)
assert.deepEqual(windowFor(0, 0, 5), [])
assert.deepEqual(windowFor(0, 1, 5), [{imageIndex: 0, offset: 0}])
assert.deepEqual(windowFor(0, 2, 5).map(row => row.imageIndex), [0, 1])
assert.deepEqual(windowFor(0, 101, 2).map(row => row.imageIndex), [0, 1, 100, 2, 99])
assert.deepEqual(windowFor(100, 101, 2).map(row => row.imageIndex), [100, 0, 99, 1, 98])
assert.ok(contains(30, 0, 100, 200, 26))
assert.ok(!contains(9, 0, 100, 200, 26))
assert.ok(!contains(98, 200, 100, 200, 26))

const entries = []
let created = 0
let removed = 0
const model = {
  get count() { return entries.length },
  get(i) { return entries[i] },
  remove(i) { removed++; entries.splice(i, 1) },
  setProperty(i, property, value) { entries[i][property] = value },
  append(row) { created++; entries.push(row) },
}
sync(model, windowFor(0, 101, 4))
const remembered = entries.find(row => row.imageIndex === 1)
sync(model, windowFor(1, 101, 4))
assert.equal(created, 10)
assert.equal(removed, 1)
assert.equal(entries.find(row => row.imageIndex === 1), remembered)
assert.equal(remembered.offset, 0)
sync(model, windowFor(0, 101, 4))
sync(model, windowFor(100, 101, 4))
assert.equal(created, 12)
assert.equal(removed, 3)
assert.equal(entries.find(row => row.imageIndex === 100).offset, 0)
console.log('Wallpaper carousel bounds, wrap and delegate reuse passed')
