const assert = require('node:assert/strict')
const Model = require('./Model.js')

assert.deepEqual(Model.focusDispatchArgs(2), ['dispatch', 'hl.dsp.focus({ workspace = "2" })'])
assert.deepEqual(Model.focusDispatchArgs('10'), ['dispatch', 'hl.dsp.focus({ workspace = "10" })'])
assert.deepEqual(Model.focusDispatchArgs(0), [])
assert.deepEqual(Model.focusDispatchArgs('2; exec bad'), [])

console.log('Workspace dispatch tests passed')
