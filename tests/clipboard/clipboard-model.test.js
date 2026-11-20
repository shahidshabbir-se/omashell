const assert = require('node:assert/strict')
const { colorChannels, classify, filter } = require('../../modules/clipboard/ClipboardModel.js')

assert.deepEqual(colorChannels(' #F80 '), [1, 136 / 255, 0, 1])
assert.deepEqual(colorChannels('#0f08'), [0, 1, 0, 136 / 255])
assert.deepEqual(colorChannels('#ffaa0080'), [1, 170 / 255, 0, 128 / 255])
assert.equal(colorChannels('border: #ffaa00'), null)
assert.equal(colorChannels('#abcd0'), null)

const entries = [
  ['text/plain;charset=utf-8', '#ffaa00'],
  ['text/plain;charset=utf-8', 'https://example.org/Orange'],
  ['text/plain;charset=utf-8', 'An orange note'],
  ['text/uri-list', 'https://example.org/orange'],
  ['image/png', 'PNG image']
].map(([mime, preview], id) => classify({ id, mime, preview }))

assert.deepEqual(entries.map(entry => entry.type), ['colors', 'links', 'text', 'files', 'images'])
assert.deepEqual(filter(entries, 'all', ' ORANGE ').map(entry => entry.id), [1, 2, 3])
assert.deepEqual(filter(entries, 'links', 'orange').map(entry => entry.id), [1])
assert.deepEqual(filter(entries, 'colors', 'orange'), [])
assert.equal(filter(entries, 'colors', '')[0].preview, '#ffaa00')
console.log('Clipboard model tests passed')
