const assert = require("node:assert/strict")
const Model = require("./Model.js")

const address = "AA:BB:CC:DD:EE:FF"
const pendingConnect = { [address]: "connect" }

// A connected device must stop displaying Connecting even if the command process
// has not exited yet.
assert.deepEqual(
  Model.syncPending(pendingConnect, [{ address, connected: true }]),
  {}
)
assert.equal(
  Model.statusText({ connected: true, battery: 70 }, "connect"),
  "Connecting…"
)
assert.equal(
  Model.statusText({ connected: true, battery: 70 }, ""),
  "70%"
)

// Disconnect stays pending until BlueZ reports the link down.
assert.deepEqual(
  Model.syncPending({ [address]: "disconnect" }, [{ address, connected: true }]),
  { [address]: "disconnect" }
)
assert.deepEqual(
  Model.syncPending({ [address]: "disconnect" }, [{ address, connected: false }]),
  {}
)

// Forget clears when the device disappears or loses its pairing record.
assert.deepEqual(Model.syncPending({ [address]: "forget" }, []), {})
assert.deepEqual(
  Model.syncPending({ [address]: "forget" }, [{ address, paired: false, bonded: false, trusted: false }]),
  {}
)

console.log("Bluetooth pending-state tests passed")
