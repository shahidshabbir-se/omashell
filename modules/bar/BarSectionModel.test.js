const assert = require('node:assert/strict')
const Model = require('./BarSectionModel.js')

assert.equal(Model.indicatorWidth(27, 0, 0, 10), 15)
assert.equal(Model.indicatorWidth(118, 0, 0, 10), 65)
assert.equal(Model.indicatorWidth(118, 0, 100, 10), 100)
assert.equal(Model.indicatorWidth(40, 20, 0, 10), 11)
assert.equal(Model.indicatorWidth(40, 30, 0, 10), 17)
assert.equal(Model.indicatorWidth(40, 0, 16, 10), 16)
assert.equal(Model.indicatorWidth(12, 0, 0, 10), 10)

console.log('Bar indicator geometry tests passed')
