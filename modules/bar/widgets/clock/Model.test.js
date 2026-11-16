const assert = require('node:assert/strict')
const Model = require('./Model.js')

assert.deepEqual(Model.CLOCK_FORMATS, [
  'dddd HH:mm',
  'dddd h:mm AP',
  'dddd HH:mm:ss',
  'dddd h:mm:ss AP',
  'HH:mm',
  'h:mm AP',
  'ddd d MMM HH:mm',
  'ddd d MMM h:mm AP',
  'd MMMM \'W\'ww yyyy',
  'yyyy-MM-dd HH:mm'
])
assert.deepEqual(Model.VERTICAL_CLOCK_FORMATS, [
  'HH\n—\nmm',
  'h\n—\nmm\nAP',
  'dd\nMMM\n\'W\'ww\n\'\'yy',
  'HH\nmm'
])

// Seconds are only requested when the format prints them, and quoted literals
// are text rather than tokens.
assert.equal(Model.clockNeedsSeconds('HH:mm'), false)
assert.equal(Model.clockNeedsSeconds('dddd HH:mm:ss'), true)
assert.equal(Model.clockNeedsSeconds('h:mm:ss AP'), true)
assert.equal(Model.clockNeedsSeconds('HH:mm \'secs\''), false)
assert.equal(Model.clockNeedsSeconds('HH:mm \'s'), false)
assert.equal(Model.clockNeedsSeconds(undefined), false)

assert.equal(Model.formatKey(false), 'format')
assert.equal(Model.formatKey(true), 'verticalFormat')
assert.equal(Model.altFormatKey(false), 'formatAlt')
assert.equal(Model.altFormatKey(true), 'verticalFormatAlt')
assert.equal(Model.defaultFormat(false), 'dddd HH:mm')
assert.equal(Model.defaultFormat(true), 'HH\n—\nmm')
assert.equal(Model.defaultAltFormat(false), 'd MMMM \'W\'ww yyyy')
assert.equal(Model.defaultAltFormat(true), 'dd\nMMM\n\'W\'ww\n\'\'yy')

// A legacy numeric preset is read once, then persisted as a format string.
assert.equal(Model.formatFromSetting(4, false), 'HH:mm')
assert.equal(Model.formatFromSetting(2, true), 'dd\nMMM\n\'W\'ww\n\'\'yy')
assert.equal(Model.formatFromSetting(99, false), 'dddd HH:mm')
assert.equal(Model.formatFromSetting('HH:mm', false), 'HH:mm')
assert.equal(Model.formatFromSetting(undefined, true), 'HH\n—\nmm')
assert.equal(Model.altFormatFromSetting(undefined, false), 'd MMMM \'W\'ww yyyy')
assert.equal(Model.altFormatFromSetting(undefined, true), 'dd\nMMM\n\'W\'ww\n\'\'yy')
assert.equal(Model.altFormatFromSetting('', false), '')
assert.equal(Model.altFormatFromSetting('yyyy-MM-dd', false), 'yyyy-MM-dd')

// The ring walks the presets, then the alternate and current when they are
// custom, without duplicates and without reordering around the current value.
const horizontalRing = Model.clockFormatRing('HH:mm', 'yyyy-MM-dd', Model.clockFormats(false))
assert.equal(horizontalRing[0], 'dddd HH:mm')
assert.equal(horizontalRing.indexOf('yyyy-MM-dd'), horizontalRing.length - 1)
assert.equal(horizontalRing.indexOf('HH:mm'), 4)
assert.equal(Model.nextClockFormat(['a', 'b', 'c'], 'a'), 'b')
assert.equal(Model.nextClockFormat(['a', 'b', 'c'], 'c'), 'a')
assert.equal(Model.nextClockFormat(['a', 'b', 'c'], 'missing'), 'a')
assert.equal(Model.nextClockFormat([], 'a'), '')
assert.deepEqual(Model.clockFormatRing('', '', []), ['HH:mm'])

const verticalRing = Model.clockFormatRing('HH\n—\nmm', Model.defaultAltFormat(true), Model.clockFormats(true))
assert.deepEqual(verticalRing, Model.VERTICAL_CLOCK_FORMATS)

// A right click persists the next format under the orientation's own key.
const horizontalCycle = Model.cycleClockFormat({ format: 'HH:mm' }, false)
assert.equal(horizontalCycle.key, 'format')
assert.equal(horizontalCycle.current, 'HH:mm')
assert.equal(horizontalCycle.next, 'h:mm AP')
assert.equal(horizontalCycle.ring.indexOf('d MMMM \'W\'ww yyyy'), horizontalCycle.ring.length - 2)

const verticalCycle = Model.cycleClockFormat({ verticalFormat: 'HH\n—\nmm' }, true)
assert.equal(verticalCycle.key, 'verticalFormat')
assert.equal(verticalCycle.next, 'h\n—\nmm\nAP')

const legacyCycle = Model.cycleClockFormat({ format: 4 }, false)
assert.equal(legacyCycle.current, 'HH:mm')
assert.equal(legacyCycle.next, 'h:mm AP')

// ISO week is the week owning that date's Thursday.
assert.equal(Model.isoWeek(2021, 0, 1), 53)
assert.equal(Model.isoWeekLiteral(2021, 0, 1), '53')
assert.equal(Model.isoWeek(2024, 11, 30), 1)
assert.equal(Model.isoWeek(2026, 0, 1), 1)
assert.equal(Model.isoWeekLiteral(2024, 11, 30), '01')
assert.equal(Model.applyWeek('d MMMM \'W\'ww yyyy', '01'), 'd MMMM \'W\'01 yyyy')
assert.equal(Model.applyWeek('dd\nMMM\n\'W\'ww\n\'\'yy', '53'), 'dd\nMMM\n\'W\'53\n\'\'yy')
assert.deepEqual(Model.displayLines('dd\nMMM\n\'W\'ww'), ['dd', 'MMM', "'W'ww"])

// Re-arming from the epoch clock keeps the delay inside one step.
assert.equal(Model.msUntilNextTick(0, 1000), 1000)
assert.equal(Model.msUntilNextTick(1234, 1000), 766)
assert.equal(Model.msUntilNextTick(60000, 60000), 60000)
assert.equal(Model.msUntilNextTick(1234, 60000), 58766)
assert.equal(Model.msUntilNextTick(1234, 0), 58766)

// The result of a right click goes through the same bar-config mutation the
// widget calls, and lands as a string in the orientation's own key.
const BarModel = require('../../BarModel.js')
const sections = { left: [], centerBegin: [], center: ['clock'], centerEnd: [], right: [] }
const cycle = Model.cycleClockFormat({ format: 'HH:mm' }, false)
assert.equal(BarModel.setWidgetSetting(sections, 'clock', cycle.key, cycle.next), true)
assert.deepEqual(sections.center, [{ id: 'clock', format: 'h:mm AP' }])

const verticalSections = { left: [], centerBegin: [], center: [{ id: 'clock', verticalFormat: 'HH\n—\nmm' }], centerEnd: [], right: [] }
const verticalStep = Model.cycleClockFormat(verticalSections.center[0], true)
assert.equal(BarModel.setWidgetSetting(verticalSections, 'clock', verticalStep.key, verticalStep.next), true)
assert.equal(verticalSections.center[0].verticalFormat, 'h\n—\nmm\nAP')

console.log('Clock model tests passed')
