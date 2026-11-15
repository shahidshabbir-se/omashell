const assert = require('node:assert/strict')
const model = require('./Model.js')

assert.equal(model.clamp(-1, 1), 0)
assert.equal(model.clamp(3, 1.5), 1.5)
assert.equal(model.clamp(NaN, 1), 0)
assert.equal(model.volumeIcon(null, 1, false), '')
assert.equal(model.volumeIcon({name: 'speakers'}, 0.3, false), '')
assert.equal(model.volumeIcon({name: 'speakers'}, 0.5, false), '')
assert.equal(model.volumeIcon({name: 'speakers'}, 0.9, false), '')
assert.equal(model.volumeIcon({name: 'speakers'}, 0.9, true), '')
assert.equal(model.volumeIcon({name: 'headphones'}, 0.9, false), '󰋋')
const nodes = [{id: 1, name: 'first'}, {id: 2, name: 'second'}]
const rows = model.snapshot(nodes, n => n.id === 1)
assert.deepEqual(rows, [{id: 1, name: 'first'}])
assert.equal(model.findNode(nodes, rows[0]), nodes[0])
assert.equal(model.findNode([{id: 1, name: 'reused'}], rows[0]), null)
assert.equal(model.findNode([], rows[0]), null)
assert.equal(model.streamLabel({name: 'fallback', ready: true, properties: {'application.name': 'Music'}}), 'Music')
assert.deepEqual(model.outputAvailability('not json'), {})
assert.deepEqual(model.outputAvailability(JSON.stringify([
  {name: 'missing', ports: [{availability: 'not available'}]},
  {name: 'ready', ports: [{availability: 'not available'}, {availability: 'available'}]},
  {name: 'unknown', ports: [{availability: 'unknown'}]},
  {name: 'virtual', ports: []}
])), {missing: false, ready: true, unknown: true})
console.log('Audio model tests passed')
