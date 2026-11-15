const assert = require('node:assert/strict')
const model = require('./WifiQrModel.js')
assert.deepEqual(model.parseQrOutput('meta\twlan0\tWPA\tMy\tSSID\n10\n01\n'), {
  meta: { iface: 'wlan0', security: 'WPA', ssid: 'My\tSSID' },
  matrix: { rows: ['10', '01'], size: 2 }
})
assert.deepEqual(model.parseQrMatrix(['10', '0']), { rows: [], size: 0 })
assert.deepEqual(model.parseQrMatrix(['10', 'ab']), { rows: [], size: 0 })
assert.deepEqual(model.parseQrMatrix(['101']), { rows: [], size: 0 })
console.log('Wi-Fi QR model tests passed')
