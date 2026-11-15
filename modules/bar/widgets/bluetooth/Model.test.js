const assert = require("node:assert/strict")
const Model = require("./Model.js")

const address = "AA:BB:CC:DD:EE:FF"
const pendingConnect = { [address]: "connect" }

                                                                                 
                      
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

                                                              
assert.deepEqual(
  Model.syncPending({ [address]: "disconnect" }, [{ address, connected: true }]),
  { [address]: "disconnect" }
)
assert.deepEqual(
  Model.syncPending({ [address]: "disconnect" }, [{ address, connected: false }]),
  {}
)

                                                                        
assert.deepEqual(Model.syncPending({ [address]: "forget" }, []), {})
assert.deepEqual(
  Model.syncPending({ [address]: "forget" }, [{ address, paired: false, bonded: false, trusted: false }]),
  {}
)

console.log("Bluetooth pending-state tests passed")
