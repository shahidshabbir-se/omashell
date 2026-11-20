const assert = require('node:assert/strict')
const { rect, overlaps, bounds, place } = require('../../modules/display/Arrangement.js')

assert.deepEqual(rect({ x: -720, y: 30, width: 1920, height: 1080, scale: 1.5, transform: 1 }),
  { x: -720, y: 30, width: 720, height: 1280 })

const primary = { x: 0, y: 0, width: 1000, height: 700 }
const moving = { x: 1000, y: 0, width: 600, height: 400 }
assert.equal(overlaps(primary, moving), false)
assert.deepEqual(bounds([primary, { ...moving, x: -600, y: -400 }]),
  { x: -600, y: -400, width: 1600, height: 1100 })
assert.deepEqual(place(moving, [primary], 991, 26, 20), { x: 1000, y: 26 })
assert.deepEqual(place(moving, [primary], -592, 50, 20), { x: -600, y: 50 })
assert.deepEqual(place(moving, [primary], 20, -410, 20), { x: 20, y: -400 })
assert.equal(place(moving, [primary], 200, 200, 20), null)
assert.equal(place(moving, [primary, { ...moving, x: 1000, y: 0 }], 991, 26, 20), null)
assert.deepEqual(place(moving, [primary], 1210, 900, 20), { x: 1210, y: 900 })
console.log('Display arrangement tests passed')
