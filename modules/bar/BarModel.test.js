const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')
const Model = require('./BarModel.js')

const defaults = { left: ['logo'], centerBegin: ['indicators'], center: ['clock'], centerEnd: ['worldclock', 'weather'], right: ['network'] }
const migrated = Model.normalizeConfig({ version: 1, bar: { left: ['custom'], center: ['clock'], right: ['audio'] } }, defaults)
assert.deepEqual(migrated.bar.left, ['custom'])
assert.deepEqual(migrated.bar.centerBegin, ['indicators'])
assert.deepEqual(migrated.bar.centerEnd, ['worldclock', 'weather'])
assert.equal(migrated.bar.position, 'top')

const legacy = Model.normalizeConfig({ bar: { layout: { left: ['a'], center: ['b'], right: ['c'] } } }, defaults)
assert.deepEqual(legacy.bar.centerBegin, ['indicators'])
assert.equal('layout' in legacy.bar, false)

const sections = { left: ['a'], centerBegin: ['indicators'], center: ['clock'], centerEnd: ['weather'], right: ['audio'] }
assert.equal(Model.moveWidget(sections, { section: 'centerEnd', index: 0 }, { section: 'centerBegin', index: 1 }), true)
assert.deepEqual(sections.centerBegin, ['indicators', 'weather'])
assert.deepEqual(sections.centerEnd, [])
assert.equal(Model.moveWidget(sections, { section: 'centerBegin', index: 0 }, { section: 'right', index: 0 }), true)
assert.deepEqual(sections.right, ['indicators', 'audio'])
assert.equal(Model.removeWidget(sections, 'right', 0), 'indicators')
assert.equal(Model.addWidget(sections, 'centerEnd', 'notifications'), true)
assert.equal(Model.addWidget(sections, 'right', 'notifications'), false)
assert.equal(Model.addWidget(sections, 'right', 'stayAwake'), true)
const configured = { left: ['logo'], centerBegin: [], center: ['clock'], centerEnd: [], right: [] }
assert.equal(Model.setWidgetSetting(configured, 'clock', 'format', 4), true)
assert.deepEqual(configured.center, [{ id: 'clock', format: 4 }])
assert.equal(Model.setWidgetSetting(configured, 'clock', 'format', 4), false)
assert.equal(Model.setWidgetSetting(configured, 'missing', 'format', 4), false)

// A hidden or malformed entry ahead of a widget must not shift a move or a
// removal onto a neighbour: identity, not the drawn index, is the key.
const hidden = { left: ['a', 'battery', 'b'], centerBegin: [], center: [], centerEnd: [], right: [] }
assert.equal(Model.removeWidgetById(hidden, 'left', 'b'), 'b')
assert.deepEqual(hidden.left, ['a', 'battery'])
const malformed = { left: ['a', { nope: true }, 'b'], centerBegin: [], center: [], centerEnd: [], right: [] }
assert.equal(Model.removeWidgetById(malformed, 'left', 'b'), 'b')
assert.deepEqual(malformed.left, ['a', { nope: true }])
const identity = { left: ['a', 'battery', 'b'], centerBegin: [], center: [], centerEnd: [], right: [] }
assert.equal(Model.moveWidgetById(identity, { region: 'left', id: 'b' }, { region: 'left', key: 'a', after: false }), true)
assert.deepEqual(identity.left, ['b', 'a', 'battery'])
assert.equal(Model.moveWidgetById(identity, { region: 'left', id: 'b' }, { region: 'left', key: 'b', after: false }), false)
assert.equal(Model.moveWidgetById(identity, { region: 'left', id: 'b' }, { region: 'left', key: 'b', after: true }), false)
const cross = { left: ['a'], centerBegin: [], center: [], centerEnd: [], right: ['b', 'c'] }
assert.equal(Model.moveWidgetById(cross, { region: 'left', id: 'a' }, { region: 'right', key: 'b', after: false }), true)
assert.deepEqual(cross.right, ['a', 'b', 'c'])
assert.equal(Model.moveWidgetById(cross, { region: 'right', id: 'a' }, { region: 'right', key: 'c', after: true }), true)
assert.deepEqual(cross.right, ['b', 'c', 'a'])
assert.equal(Model.moveWidgetById(cross, { region: 'right', id: 'a' }, { region: 'center', after: true }), true)
assert.deepEqual(cross.center, ['a'])
assert.equal(Model.moveWidgetById(cross, { region: 'center', id: 'missing' }, { region: 'right', after: true }), false)
assert.equal(Model.moveWidgetById(cross, { region: 'center', id: 'a' }, { region: 'right', key: 'missing', after: false }), false)

assert.deepEqual(Model.layoutKeys({ left: ['a', { id: 'b' }], centerBegin: ['c'], center: ['d'], centerEnd: [], right: [] }), {
  left: ['a', 'b'], centerBegin: ['c'], center: ['d'], centerEnd: [], right: []
})

const candidates = [
  { key: 'a', region: 'left', x: 0, y: 0, width: 20, height: 28 },
  { key: 'b', region: 'right', x: 100, y: 0, width: 20, height: 28 }
]
assert.deepEqual(Model.nearestDropTarget(candidates, { x: 80, y: 14 }, false), { region: 'right', key: 'b', after: false, distance: 20 })
assert.deepEqual(Model.nearestDropTarget(candidates, { x: 30, y: 14 }, false), { region: 'left', key: 'a', after: true, distance: 10 })
assert.equal(Model.nearestDropTarget(candidates, { x: NaN, y: 14 }, false), null)
assert.deepEqual(Model.centerDropZone({ x: 100, y: 0, width: 0, height: 28 }, 28, false), { x: 86, y: 0, width: 28, height: 28 })
assert.deepEqual(Model.centerDropZone({ x: 0, y: 100, width: 28, height: 0 }, 28, true), { x: 0, y: 86, width: 28, height: 28 })

const emptyCenter = { x: 100, y: 0, width: 0, height: 28 }
const emptyZone = Model.centerDropZone(emptyCenter, 28, false)
assert.deepEqual(Model.centerDropTarget(candidates, emptyZone, { x: 100, y: 14 }, false, null), { region: 'center', after: true })
assert.deepEqual(Model.centerDropTarget(candidates, emptyZone, { x: 80, y: 14 }, false, null), { region: 'centerBegin', after: true, distance: 6 })
assert.deepEqual(Model.centerDropTarget(candidates, emptyZone, { x: 10, y: 14 }, false, { key: 'a', region: 'left' }), { region: 'left', key: 'a', after: false })
const centerRows = [
  { key: 'a', region: 'left', x: 0, y: 0, width: 20, height: 28 },
  { key: 'c', region: 'center', x: 80, y: 0, width: 40, height: 28 }
]
const centerBox = { x: 80, y: 0, width: 40, height: 28 }
const centerZone = Model.centerDropZone(centerBox, 28, false)
assert.deepEqual(Model.centerDropTarget(centerRows, centerZone, { x: 100, y: 14 }, false, null), { region: 'center', key: 'c', after: false, distance: 20 })
assert.deepEqual(Model.centerDropTarget(centerRows, centerZone, { x: 119, y: 14 }, false, null), { region: 'center', key: 'c', after: true, distance: 1 })
assert.deepEqual(Model.centerDropTarget(centerRows, centerZone, { x: 300, y: 14 }, false, null), { region: 'centerEnd', after: false, distance: 180 })

const roomRows = [
  { key: 'a', region: 'left' },
  { key: 'b', region: 'left' },
  { key: 'c', region: 'right' }
]
assert.deepEqual(Model.dropRoom(null, { region: 'left', key: 'b' }, roomRows), { region: 'left', index: 1, home: true })
assert.deepEqual(Model.dropRoom({ region: 'left', key: 'a', after: true }, { region: 'left', key: 'b' }, roomRows), { region: 'left', index: 1, home: true })
assert.deepEqual(Model.dropRoom({ region: 'left', key: 'b', after: true }, { region: 'left', key: 'b' }, roomRows), { region: 'left', index: 1, home: true })
assert.deepEqual(Model.dropRoom({ region: 'left', key: 'a', after: false }, { region: 'left', key: 'b' }, roomRows), { region: 'left', index: 0, home: false })
assert.deepEqual(Model.dropRoom({ region: 'right', key: 'c', after: false }, { region: 'left', key: 'b' }, roomRows), { region: 'right', index: 0, home: false })
assert.deepEqual(Model.dropRoom({ region: 'right', after: true }, { region: 'left', key: 'b' }, roomRows), { region: 'right', index: 1, home: false })
assert.equal(Model.dropRoom(null, { region: 'left', key: 'missing' }, roomRows), null)

const faded = Model.fadeShares({ 'left:0': 0.5, 'right:0': 0.5 }, 'right:0', 0.2)
assert.deepEqual(faded, { 'left:0': 0.3, 'right:0': 0.7 })
assert.deepEqual(Model.fadeShares({ 'left:0': 1 }, 'right:2', 0.25), { 'left:0': 0.75, 'right:2': 0.25 })
assert.deepEqual(Model.fadeShares({ 'left:0': 0.2 }, '', 0.5), {})
assert.deepEqual(Model.roomLengths(100, { 'a': 0.333, 'b': 0.667 }), { a: 33, b: 67 })
assert.deepEqual(Model.roomLengths(10, { 'a': 1 }), { a: 10 })
assert.deepEqual(Model.roomLengths(0, { 'a': 1 }), {})

assert.deepEqual(Model.centerGeometry(1920, 80, 100, 60), { center: 910, begin: 830, end: 1010 })
assert.equal(Model.revealed(true, false), true)
assert.equal(Model.revealed(false, false), false)
assert.equal(Model.revealed(false, true), true)
assert.equal(Model.dragDistanceOutside({ x: 50, y: 10 }, 100, 28), 0)
assert.equal(Model.dragDistanceOutside({ x: 50, y: 80 }, 100, 28), 52)
assert.equal(Model.dragDistanceOutside({ x: -3, y: -4 }, 100, 28), 5)

// A partial user config keeps the built-in sections it omits. Config.bar and
// Bar's own layout reads must pass the defaults here, not {}, or a drag would
// write a layout with missing sections erased.
const partial = { bar: { left: ['logo'] } }
const partialSections = Model.configSections(partial, defaults)
assert.deepEqual(partialSections.left, ['logo'])
assert.deepEqual(partialSections.centerBegin, defaults.centerBegin)
assert.deepEqual(partialSections.center, defaults.center)
assert.deepEqual(partialSections.centerEnd, defaults.centerEnd)
assert.deepEqual(partialSections.right, defaults.right)
assert.deepEqual(Model.configSections({}, defaults), defaults)
assert.deepEqual(Model.configSections({ bar: { left: ['only'] } }, defaults), {
  left: ['only'],
  centerBegin: defaults.centerBegin,
  center: defaults.center,
  centerEnd: defaults.centerEnd,
  right: defaults.right
})

// Guard the caller itself: Bar.qml must use Config.defaults.bar as the fallback.
const barSource = fs.readFileSync(path.join(__dirname, 'Bar.qml'), 'utf8')
assert.match(barSource, /function configSections\(\)\s*\{\s*return BarModel\.configSections\(Config\.raw || Config\.defaults, Config\.defaults\.bar\)/)
assert.equal(/Config\.raw \? \{\} : Config\.defaults\.bar/.test(barSource), false)

console.log('Bar layout model tests passed')
