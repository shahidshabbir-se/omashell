const assert = require('node:assert/strict')
const Model = require('./Model.js')

assert.deepEqual(Model.focusDispatchArgs(2), ['dispatch', 'hl.dsp.focus({ workspace = "2" })'])
assert.deepEqual(Model.focusDispatchArgs('10'), ['dispatch', 'hl.dsp.focus({ workspace = "10" })'])
assert.deepEqual(Model.focusDispatchArgs(0), [])
assert.deepEqual(Model.focusDispatchArgs('2; exec bad'), [])

// A horizontal workspaces row is 20px wide and as tall as the bar. Vertical
// rows use the bar's full thickness in both directions, as the reference bar
// does, and have a slightly larger gap between them.
assert.deepEqual(Model.slotMetrics(false, 28), {
  width: 20,
  height: 28,
  spacing: 1,
  trailingGap: 1.5
})
assert.deepEqual(Model.slotMetrics(true, 28), {
  width: 28,
  height: 28,
  spacing: 2,
  trailingGap: 0
})

// Wheel-up moves toward the start of the bar and wheel-down toward its end,
// whichever edge the bar is on. Both stop at the ends instead of wrapping.
assert.equal(Model.scrollTarget([1, 2, 3, 5], 2, 1), 1)
assert.equal(Model.scrollTarget([1, 2, 3, 5], 2, -1), 3)
assert.equal(Model.scrollTarget([1, 2, 3, 5], 1, 1), 1)
assert.equal(Model.scrollTarget([1, 2, 3, 5], 5, -1), 5)
assert.equal(Model.scrollTarget([1, 2, 3, 5], 3, 0), 3)
assert.equal(Model.scrollTarget([1, 2, 3, 5], 9, -1), null)
assert.equal(Model.scrollTarget([], 1, -1), null)

console.log('Workspace layout and dispatch tests passed')
