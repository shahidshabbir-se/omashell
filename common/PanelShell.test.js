// PanelShell keeps its placement maths in QML functions so it can work per
// edge without duplicating bindings. This test lifts those functions out of
// the QML source and runs them under Node, covering all four bar edges.

const assert = require('node:assert/strict')
const fs = require('node:fs')
const path = require('node:path')

function functionSource(source, name) {
  const marker = 'function ' + name + '('
  const start = source.indexOf(marker)
  assert.notEqual(start, -1, name + ' is declared in PanelShell.qml')
  const open = source.indexOf('{', start)
  let depth = 0
  for (let i = open; i < source.length; i++) {
    if (source[i] === '{') depth++
    else if (source[i] === '}') {
      depth--
      if (depth === 0) return source.slice(start, i + 1)
    }
  }
  assert.fail(name + ' has a closing brace')
}

const qml = fs.readFileSync(path.join(__dirname, 'PanelShell.qml'), 'utf8')
const source = [
  'anchorAlongFor', 'clamp', 'fitCardWidth', 'fitCardHeight', 'cardPosition'
].map(name => functionSource(qml, name)).join('\n')
const functions = new Function(source +
  '\nreturn { anchorAlongFor, clamp, fitCardWidth, fitCardHeight, cardPosition }')()

const screen = { width: 1920, height: 1080 }
const bar = 28
const gap = 5
const card = { width: 340, height: 200 }

// A vertical bar takes the along-bar anchor from anchorY, or from the
// along-bar coordinate the bar currently passes in anchorX. With neither it
// opens centered, while a horizontal bar keeps its existing fallback.
assert.equal(functions.anchorAlongFor('left', 300, -1, screen.width, screen.height), 300)
assert.equal(functions.anchorAlongFor('right', 300, -1, screen.width, screen.height), 300)
assert.equal(functions.anchorAlongFor('left', -1, 200, screen.width, screen.height), 200)
assert.equal(functions.anchorAlongFor('right', -1, 200, screen.width, screen.height), 200)
assert.equal(functions.anchorAlongFor('left', -1, -1, screen.width, screen.height), screen.height / 2)
assert.equal(functions.anchorAlongFor('left', 0, -1, screen.width, screen.height), 0)
assert.equal(functions.anchorAlongFor('top', 500, 200, screen.width, screen.height), 500)
assert.equal(functions.anchorAlongFor('bottom', 500, 200, screen.width, screen.height), 500)
assert.equal(functions.anchorAlongFor('top', -1, 200, screen.width, screen.height), screen.width - 100)

// Fitting depends on the edge, not the panel: vertical bars reduce width,
// horizontal bars reduce height.
assert.equal(functions.fitCardWidth(5000, screen.width, false, bar, gap), screen.width - gap * 2)
assert.equal(functions.fitCardWidth(5000, screen.width, true, bar, gap), screen.width - bar - gap * 2)
assert.equal(functions.fitCardHeight(2000, screen.height, false, bar, gap), screen.height - bar - gap * 2)
assert.equal(functions.fitCardHeight(2000, screen.height, true, bar, gap), screen.height - gap * 2)
assert.equal(functions.fitCardWidth(100, screen.width, true, bar, gap), 100)
assert.equal(functions.fitCardHeight(100, screen.height, false, bar, gap), 100)
// Before the panel window is mapped it has no size; the wanted card is kept.
assert.equal(functions.fitCardWidth(340, 0, true, bar, gap), 340)
assert.equal(functions.fitCardHeight(300, 0, false, bar, gap), 300)

const place = (position, anchor, wanted = card) => functions.cardPosition(anchor,
  screen.width, screen.height, position, bar, gap,
  functions.fitCardWidth(wanted.width, screen.width, position === 'left' || position === 'right', bar, gap),
  functions.fitCardHeight(wanted.height, screen.height, position === 'left' || position === 'right', bar, gap))

// Top and bottom bars place the card on the desktop side and center it on
// the widget, clamped to the screen.
assert.deepEqual(place('top', 500), { x: 330, y: 33 })
assert.deepEqual(place('bottom', 500), { x: 330, y: 847 })
assert.equal(place('top', 1920).x, 1920 - 340 - gap)

// Left and right bars place the card beside the bar, centered vertically on
// the widget and clamped above and below.
assert.deepEqual(place('left', 500), { x: 33, y: 400 })
assert.deepEqual(place('right', 500), { x: 1547, y: 400 })
assert.equal(place('left', 0).y, gap)
assert.equal(place('right', 0).y, gap)
assert.equal(place('left', screen.height).y, screen.height - 200 - gap)
assert.equal(place('right', screen.height).y, screen.height - 200 - gap)

// An oversized card is fitted to the desktop area, leaving the bar and screen
// gap clear, and lands against the safe edge rather than off screen.
assert.deepEqual(place('left', 500, { width: 5000, height: 2000 }), { x: 33, y: gap })
assert.deepEqual(place('right', 500, { width: 5000, height: 2000 }), { x: gap, y: gap })
assert.deepEqual(place('top', 500, { width: 5000, height: 2000 }), { x: gap, y: 33 })
assert.deepEqual(place('bottom', 500, { width: 5000, height: 2000 }), { x: gap, y: gap })

console.log('Panel placement tests passed')
