const assert = require("node:assert/strict")
const Model = require("./Model.js")

                            
assert.deepEqual(Model.parseNetworkStatus("wifi\tHomeNet\t72\t5745.0"), {
  kind: "wifi", label: "HomeNet", signalStrength: 72, frequency: "5745.0"
})
assert.deepEqual(Model.parseNetworkStatus(""), {
  kind: "disconnected", label: "", signalStrength: -1, frequency: ""
})
assert.equal(Model.parseNetworkStatus("disconnected\t\t\t").kind, "disconnected")

                                                         
assert.equal(Model.wifiIconFor(0), Model.wifiIconFor(1))
assert.notEqual(Model.wifiIconFor(10), Model.wifiIconFor(90))
assert.equal(Model.connectionIcon("disconnected", 0, "none"), "\u{f092e}")
assert.equal(Model.connectionIcon("ethernet", 0, "full"), "\u{f0200}")
assert.equal(Model.connectionIcon("ethernet", 0, "portal"), "\u{f0202}")
assert.equal(Model.connectionIcon("wifi", 90, "portal"), "\u{f0929}")
assert.equal(Model.connectionIcon("wifi", 90, "full"), Model.wifiIconFor(90))

                                                                       
assert.equal(Model.connectedSignalStrength(0.8, 10), 80)
assert.equal(Model.connectedSignalStrength(0, 55), 55)
assert.equal(Model.connectedSignalStrength(0, -1), 0)
assert.equal(Model.parseActiveApSignal(" :45\n*:78\n"), 78)
assert.equal(Model.parseActiveApSignal(" :45\n :60\n"), -1)

                       
const states = { None: 1, Portal: 2, Limited: 3, Full: 4 }
assert.equal(Model.connectivityState("disconnected", states.Full, states, true), "none")
assert.equal(Model.connectivityState("wifi", states.Full, states, true), "full")
assert.equal(Model.connectivityState("wifi", states.Portal, states, true), "portal")
assert.equal(Model.connectivityState("wifi", states.Limited, states, true), "limited")
assert.equal(Model.connectivityState("wifi", states.Full, states, false), "unknown")
assert.equal(Model.connectivityState("wifi", 99, states, true), "unknown")

                                                            
assert.equal(Model.formatHeaderSpeed(1000), "1gbit")
assert.equal(Model.formatHeaderSpeed(2500), "2.5gbit")
assert.equal(Model.formatHeaderSpeed(0), "")
assert.equal(Model.formatHeaderFreq(2412), "2.4ghz")
assert.equal(Model.formatHeaderFreq(5180), "5ghz")
assert.equal(Model.formatHeaderFreq(5955), "6ghz")
assert.equal(Model.formatHeaderFreq(0), "")
assert.equal(Model.headerDetail({ type: "ethernet", speed: "1000" }), "1gbit")
assert.equal(Model.headerDetail({ type: "wifi", speed: "1000" }), "")

                           
assert.equal(Model.bandLabel("auto"), "Auto")
assert.equal(Model.bandLabel("2.4"), "2.4ghz")
assert.equal(Model.bandLabel(""), "")
assert.equal(Model.bandSectionTitle("auto", "5"), "WI-FI BAND: 5GHZ")
assert.equal(Model.bandSectionTitle("5", "5"), "WI-FI BAND")
assert.equal(Model.bandSectionTitle("auto", ""), "WI-FI BAND")
assert.equal(Model.bandTooltip("auto"), "Let Wi-Fi pick the band")
assert.equal(Model.bandTooltip("5"), "Stay on 5ghz")

assert.deepEqual(Model.parseBandStatus("band\t5\navailable\t2.4 5\nselected\tauto\n"), {
  band: "5", selected: "auto", available: ["2.4", "5"]
})
assert.deepEqual(Model.parseBandStatus(""), { band: "", selected: "auto", available: [] })

                                         
assert.equal(Model.decodeIwSsid("Caf\\xC3\\xA9"), "Café")
assert.equal(Model.decodeIwSsid("A\\x20B"), "A B")
assert.equal(Model.decodeIwSsid("plain"), "plain")
assert.deepEqual(Model.parseKeyValue("iface\twlan0\nssid\tCaf\\xC3\\xA9\nrx_bytes\t1024\n"), {
  iface: "wlan0", ssid: "Café", rx_bytes: "1024"
})
assert.deepEqual(Model.parseKeyValue(""), {})

                                                                             
const first = Model.throughputState({}, { iface: "wlan0", rx_bytes: "500", tx_bytes: "100" }, 10)
assert.equal(first.downloadRate, 0)
assert.equal(first.prevSampleTime, 10)
const second = Model.throughputState(first, { iface: "wlan0", rx_bytes: "2500", tx_bytes: "300" }, 12)
assert.equal(second.downloadRate, 1000)
assert.equal(second.uploadRate, 100)
const switched = Model.throughputState(second, { iface: "eth0", rx_bytes: "3000", tx_bytes: "400" }, 20)
assert.equal(switched.downloadRate, 0)
assert.equal(switched.prevIface, "eth0")
                                              
assert.equal(Model.throughputState(second, { iface: "wlan0", rx_bytes: "0", tx_bytes: "0" }, 13).downloadRate, 0)

                                                                       
const pings = Model.pingLatencyState({}, { iface: "wlan0", router_ping_ms: "2", internet_ping_ms: "20" }, 3, 2)
assert.equal(pings.routerPingLatency, 2)
assert.equal(pings.internetPingLatency, 20)
assert.equal(pings.internetPingPacketLoss, 0)
const lost = Model.pingLatencyState(pings, { iface: "wlan0", router_ping_ms: "4", internet_ping_ms: "" }, 3, 2)
assert.equal(lost.internetPingPacketLoss, 50)
assert.equal(Model.pingPacketLossPercent([null, 5, null, null]), 75)
assert.equal(Model.pingPacketLossPercent([]), 0)
assert.equal(Model.averagePingLatency([10, 20, null], 2), 20)
assert.equal(Model.averagePingLatency([null], 1), -1)
assert.equal(Model.internetPingReadable([5], "full"), true)
assert.equal(Model.internetPingReadable([5], "portal"), false)
assert.equal(Model.internetPingReadable([], "full"), false)
                                            
assert.deepEqual(Model.pingLatencyState(pings, { iface: "eth0", internet_ping_ms: "5" }, 3, 2).internetPingSamples, [5])

assert.equal(Model.formatBytes(512), "512 B")
assert.equal(Model.formatBytes(2048), "2.0 KB")
assert.equal(Model.formatBytes(5 * 1024 * 1024), "5.0 MB")
assert.equal(Model.formatBytes(2 * 1024 * 1024 * 1024), "2.00 GB")
assert.equal(Model.formatBytes(-1), "0 B")
assert.equal(Model.formatRate(1024), "1.0 KB/s")
assert.equal(Model.formatPingLatency(-1, true), "Timeout")
assert.equal(Model.formatPingLatency(4.2, true), "4.2 ms")
assert.equal(Model.formatPingLatency(20, true), "20 ms")
assert.equal(Model.formatPingLatency(20, false), "--")
assert.equal(Model.formatPacketLoss(0, true), "0%")
assert.equal(Model.formatPacketLoss(30, true), "30%")
assert.equal(Model.formatPacketLoss(30, false), "--")

                                                  
const row = Model.wifiRow({ name: "Net", connected: true, known: false, signalStrength: 0.72, security: 4 })
assert.deepEqual(row, { connected: true, known: false, ssid: "Net", signal: 72, security: 4 })
assert.equal(Model.wifiRow(null), null)
const sorted = Model.sortWifiRows([
  { ssid: "C", connected: false, known: false, signal: 90 },
  { ssid: "B", connected: false, known: true, signal: 10 },
  { ssid: "A", connected: true, known: true, signal: 5 }
])
assert.deepEqual(sorted.map(function(n) { return n.ssid }), ["A", "B", "C"])
                                                       
assert.equal(Model.wifiSectionTitle(sorted, 0), "KNOWN NETWORKS")
assert.equal(Model.wifiSectionTitle(sorted, 1), "")
assert.equal(Model.wifiSectionTitle(sorted, 2), "OTHER NETWORKS")
assert.equal(Model.wifiSectionTitle(sorted, 3), "")

                                                  
const open = 10
const owe = 9
const unknown = 11
assert.equal(Model.requiresCredentials(open, open, owe), false)
assert.equal(Model.requiresCredentials(owe, open, owe), false)
assert.equal(Model.requiresCredentials(unknown, open, owe), true)
assert.equal(Model.canForgetNetwork({ known: true, connected: false }), true)
assert.equal(Model.canForgetNetwork({ known: true, connected: true }), false)
assert.equal(Model.canForgetNetwork({ known: false, connected: false }), false)
assert.equal(Model.canForgetNetwork(null), false)

                
const reasons = { NoSecrets: 1, WifiAuthTimeout: 4, WifiNetworkLost: 5, WifiClientDisconnected: 2, WifiClientFailed: 3 }
assert.equal(Model.networkFailureReason(reasons.WifiAuthTimeout, true, reasons), "Wrong password")
assert.equal(Model.networkFailureReason(reasons.NoSecrets, true, reasons), "Passphrase required")
assert.equal(Model.networkFailureReason(reasons.NoSecrets, false, reasons), "Failed to connect")
assert.equal(Model.networkFailureReason(reasons.WifiNetworkLost, false, reasons), "Network lost")
assert.equal(Model.shouldRepromptPassphrase(reasons.WifiAuthTimeout, true, reasons), true)
assert.equal(Model.shouldRepromptPassphrase(reasons.NoSecrets, false, reasons), false)

                                                    
assert.equal(Model.isValidIpv4("1.1.1.1"), true)
assert.equal(Model.isValidIpv4("1.1.1.256"), false)
assert.equal(Model.isValidIpv4("1.1.1"), false)
assert.equal(Model.isValidIpv6("2606:4700:4700::1111"), true)
assert.equal(Model.isValidIpv6("::1"), true)
assert.equal(Model.isValidIpv6("1:2:3:4:5:6:7:8"), true)
assert.equal(Model.isValidIpv6("1:2:3:4:5:6:7:8:9"), false)
assert.equal(Model.isValidIpv6("2001:db8::1::2"), false)
assert.equal(Model.isValidIpv6("1.1.1.1"), false)
assert.deepEqual(Model.parseDnsServers(" 1.1.1.1, 8.8.8.8 \n"), { servers: ["1.1.1.1", "8.8.8.8"], invalid: [] })
assert.deepEqual(Model.parseDnsServers("1.1.1.1 nope"), { servers: ["1.1.1.1"], invalid: ["nope"] })
assert.deepEqual(Model.parseDnsServers(""), { servers: [], invalid: [] })
assert.equal(Model.classifyDns([], "no"), "DHCP")
assert.equal(Model.classifyDns(["1.1.1.1", "1.0.0.1"], "yes"), "Cloudflare")
assert.equal(Model.classifyDns(["8.8.8.8", "8.8.4.4", "2001:4860:4860::8888", "2001:4860:4860::8844"], "yes"), "Google")
assert.equal(Model.classifyDns(["9.9.9.9"], "yes"), "Custom")
                                                        
assert.equal(Model.classifyDns(["8.8.8.8"], "no"), "DHCP")
assert.deepEqual(Model.parseDnsStatus("provider\tCloudflare\nservers\t1.1.1.1,1.0.0.1\n"), {
  provider: "Cloudflare", servers: ["1.1.1.1", "1.0.0.1"]
})
assert.deepEqual(Model.parseDnsStatus(""), { provider: "DHCP", servers: [] })

                                                      
const qr = Model.parseQrOutput("meta\twlan0\tWPA\tCafe\tNet\n1010\n0101\n")
assert.equal(qr.iface, "wlan0")
assert.equal(qr.security, "WPA")
assert.equal(qr.ssid, "Cafe\tNet")
assert.equal(qr.secured, true)
assert.equal(qr.size, 4)
assert.deepEqual(qr.rows, ["1010", "0101"])
assert.equal(Model.parseQrOutput("meta\twlan0\tnopass\tOpen\n1010\n").secured, false)
assert.deepEqual(Model.parseQrOutput(""), { iface: "", security: "", ssid: "", secured: false, rows: [], size: 0 })
                                                                         
const short = Model.parseQrOutput("1010\n011\njunk\n")
assert.equal(short.size, 4)
assert.deepEqual(short.rows, ["1010", "0110"])

                                                                
assert.equal(Model.captivePortalUrl.indexOf("omarchy"), -1)

console.log("Network model tests passed")
