const assert = require('node:assert/strict')
const Model = require('./Model.js')

assert.deepEqual(Model.DEFAULT_ITEMS, ['Dnd', 'StayAwake'])
assert.deepEqual(Model.SUPPORTED_IDS, ['Dnd', 'StayAwake'])

// Reference ids and the older Omashell spelling both resolve to the same
// indicator, including entries written as objects.
assert.equal(Model.itemId('Dnd'), 'Dnd')
assert.equal(Model.itemId({ id: 'StayAwake' }), 'StayAwake')
assert.equal(Model.itemId(null), '')
assert.equal(Model.normalizeId('Dnd'), 'Dnd')
assert.equal(Model.normalizeId(' dnd '), 'Dnd')
assert.equal(Model.normalizeId('notifications'), 'Dnd')
assert.equal(Model.normalizeId('omarchy.Dnd'), 'Dnd')
assert.equal(Model.normalizeId('StayAwake'), 'StayAwake')
assert.equal(Model.normalizeId('stayAwake'), 'StayAwake')
assert.equal(Model.normalizeId('stay-awake'), 'StayAwake')
assert.equal(Model.normalizeId('NightLight'), '')
assert.equal(Model.normalizeId(undefined), '')

assert.deepEqual(Model.normalizeItems(['notifications', 'stayAwake']), ['Dnd', 'StayAwake'])
assert.deepEqual(Model.normalizeItems(['Dnd', 'Dnd', 'StayAwake']), ['Dnd', 'StayAwake'])
assert.deepEqual(Model.normalizeItems([{ id: 'notifications' }, 'StayAwake']), ['Dnd', 'StayAwake'])
assert.deepEqual(Model.normalizeItems([]), ['Dnd', 'StayAwake'])
assert.deepEqual(Model.normalizeItems(undefined), ['Dnd', 'StayAwake'])
assert.deepEqual(Model.normalizeItems(['NightLight']), [])

// The reference default list contains indicators this independent bar does not
// implement; those are skipped rather than replaced by defaults.
const referenceDefaults = [
  'PasswordlessSudo', 'ScreenRecording', 'RemoteSession',
  'Reminder', 'NightLight', 'Dnd', 'StayAwake'
]
assert.deepEqual(Model.normalizeItems(referenceDefaults), ['Dnd', 'StayAwake'])

assert.deepEqual(Model.itemsFromSettings({}), ['Dnd', 'StayAwake'])
assert.deepEqual(Model.itemsFromSettings(null), ['Dnd', 'StayAwake'])
assert.deepEqual(Model.itemsFromSettings({ items: [] }), ['Dnd', 'StayAwake'])
assert.deepEqual(Model.itemsFromSettings({ items: ['notifications', 'stayAwake'] }), ['Dnd', 'StayAwake'])
assert.deepEqual(Model.itemsFromSettings({ items: ['NightLight'] }), [])
assert.deepEqual(Model.itemsFromSettings({ indicators: ['StayAwake'] }), ['StayAwake'])
assert.deepEqual(Model.itemsFromSettings({ items: [], indicators: ['Dnd'] }), ['Dnd'])

// Glyphs and tooltips are the reference indicator's, byte for byte.
assert.equal(Model.glyphFor('Dnd'), '\u{f009b}')
assert.equal(Model.glyphFor('notifications').codePointAt(0), 0xf009b)
assert.equal(Model.glyphFor('StayAwake'), '\u{ef59}')
assert.equal(Model.glyphFor('stayAwake').codePointAt(0), 0xef59)
assert.equal(Model.glyphFor('NightLight'), '')
assert.equal(Model.labelFor('Dnd'), 'Notifications')
assert.equal(Model.labelFor('StayAwake'), 'Stay awake')
assert.equal(Model.tooltipFor('Dnd', false), 'Silence Notifications')
assert.equal(Model.tooltipFor('Dnd', true), 'Allow Notifications')
assert.equal(Model.tooltipFor('StayAwake', false, true), 'Stay Awake')
assert.equal(Model.tooltipFor('StayAwake', true, true), 'Allow Idle Lock & Screensaver')
assert.equal(Model.tooltipFor('StayAwake', false, false), 'Stay-awake inhibition unavailable')

assert.equal(Model.isActive('Dnd', true, false), true)
assert.equal(Model.isActive('Dnd', false, true), false)
assert.equal(Model.isActive('StayAwake', false, true), true)
assert.equal(Model.isActive('notifications', true, false), true)
assert.equal(Model.isActive('NightLight', true, true), false)

// Active indicators sit against the fixed edge; revealed inactive ones grow
// on the far side and keep the active icons' click targets in place.
const ids = ['Dnd', 'StayAwake']
assert.deepEqual(Model.visibleItems(ids, true, false, false, 'start'), [
  { id: 'Dnd', active: true }
])
assert.deepEqual(Model.visibleItems(ids, false, true, false, 'start'), [
  { id: 'StayAwake', active: true }
])
assert.deepEqual(Model.visibleItems(ids, true, false, true, 'start'), [
  { id: 'Dnd', active: true },
  { id: 'StayAwake', active: false }
])
assert.deepEqual(Model.visibleItems(ids, true, false, true, 'end'), [
  { id: 'StayAwake', active: false },
  { id: 'Dnd', active: true }
])
assert.deepEqual(Model.visibleItems(ids, true, false, true, 'center'), [
  { id: 'StayAwake', active: false },
  { id: 'Dnd', active: true }
])
assert.deepEqual(Model.visibleItems(ids, true, true, false, 'start'), [
  { id: 'Dnd', active: true },
  { id: 'StayAwake', active: true }
])
assert.deepEqual(Model.visibleItems(ids, true, true, false, 'end'), [
  { id: 'StayAwake', active: true },
  { id: 'Dnd', active: true }
])
assert.deepEqual(Model.visibleItems(ids, false, false, true, 'start'), [
  { id: 'StayAwake', active: false },
  { id: 'Dnd', active: false }
])
assert.deepEqual(Model.visibleItems(ids, false, false, true, 'end'), [
  { id: 'Dnd', active: false },
  { id: 'StayAwake', active: false }
])
assert.deepEqual(Model.visibleItems(['notifications', 'StayAwake'], true, false, true, 'start'), [
  { id: 'Dnd', active: true },
  { id: 'StayAwake', active: false }
])

assert.equal(Model.indicatorOpacity(true, false), 1)
assert.equal(Model.indicatorOpacity(false, true), 0.45)
assert.equal(Model.indicatorOpacity(false, false), 0)

// BarIndicator geometry: 21x26 horizontally (status slot by reference bar
// thickness); 28x21 vertically (bar thickness by status slot).
assert.deepEqual(Model.buttonSize(false, 26, 21), { width: 21, height: 26 })
assert.deepEqual(Model.buttonSize(true, 28, 21), { width: 28, height: 21 })
assert.deepEqual(Model.widgetSize(false, 2, 28, 21), { width: 42, height: 28 })
assert.deepEqual(Model.widgetSize(true, 2, 28, 21), { width: 28, height: 42 })
assert.deepEqual(Model.widgetSize(false, 0, 28, 21), { width: 0, height: 28 })
assert.deepEqual(Model.widgetSize(true, 0, 28, 21), { width: 28, height: 0 })

// Portable stay-awake state path, under Omashell's own state directory.
assert.equal(
  Model.statePath('/tmp/state', '/home/user'),
  '/tmp/state/omashell/indicators/stay-awake'
)
assert.equal(
  Model.statePath('', '/home/user'),
  '/home/user/.local/state/omashell/indicators/stay-awake'
)
assert.equal(
  Model.stateDirectory(undefined, '/home/user'),
  '/home/user/.local/state/omashell/indicators'
)

console.log('Indicator model tests passed')
