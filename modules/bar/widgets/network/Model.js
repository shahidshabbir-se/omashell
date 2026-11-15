








function parseNetworkStatus(raw) {
  var parts = String(raw || "disconnected\t\t\t").replace(/\r?\n+$/, "").split("\t")
  return {
    kind: parts[0] || "disconnected",
    label: parts[1] || "",
    signalStrength: parts[2] ? parseInt(parts[2], 10) : -1,
    frequency: parts[3] || ""
  }
}

function wifiIconFor(strength) {
  var icons = ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]
  var index = Math.max(0, Math.min(4, Math.ceil(strength / 20) - 1))
  return icons[index]
}

                                                                               
                                                                           
                                                                                
                                                                                
function connectedSignalStrength(networkStrength, activeApSignal) {
  var strength = Math.round((networkStrength || 0) * 100)
  if (strength > 0) return strength
  return activeApSignal > 0 ? activeApSignal : strength
}

                                                                              
                                      
function parseActiveApSignal(raw) {
  var lines = String(raw || "").split(/\r?\n/)
  for (var i = 0; i < lines.length; i++) {
    var match = /^\*:(\d+)$/.exec(lines[i].trim())
    if (match) return parseInt(match[1], 10)
  }
  return -1
}

                                                                           
                                                                               
                                                                              
                                                                                
var captivePortalUrl = "http://nmcheck.gnome.org/check_network_status.txt"

function connectivityState(kind, connectivity, states, checksEnabled) {
  if (kind === "disconnected") return "none"
                                                                        
  if (!checksEnabled) return "unknown"
  if (connectivity === states.Portal) return "portal"
  if (connectivity === states.Limited) return "limited"
  if (connectivity === states.Full) return "full"
  if (connectivity === states.None) return "none"
  return "unknown"
}

function connectionIcon(kind, signalStrength, connectivity) {
  var restricted = connectivity === "portal" || connectivity === "limited"
  if (kind === "wifi") return restricted ? "󰤩" : wifiIconFor(signalStrength)
  if (kind === "ethernet") return restricted ? "󰈂" : "󰈀"
  return "󰤮"
}

                                                                      

function formatHeaderSpeed(mbps, fmt) {
  var f = formatter(fmt)
  var v = parseInt(mbps, 10)
  if (!v || v < 0) return ""
  if (v >= 1000) return f(v / 1000, v % 1000 === 0 ? 0 : 1) + "gbit"
  return f(v) + "mbit"
}

function formatHeaderFreq(mhz, fmt) {
  var f = formatter(fmt)
  var v = parseFloat(mhz)
  if (!v) return ""

  if (v >= 2400 && v < 2500) return f(2.4) + "ghz"
  if (v >= 4900 && v < 5925) return f(5) + "ghz"
  if (v >= 5925 && v < 7125) return f(6) + "ghz"
  if (v >= 57000 && v < 71000) return f(60) + "ghz"

  var ghz = v / 1000
  return f(ghz, ghz % 1 === 0 ? 0 : 1) + "ghz"
}

                                                                              
                                                                               
function headerDetail(info, fmt) {
  var value = info || {}
  if (value.type === "ethernet") return formatHeaderSpeed(value.speed || "", fmt)
  return ""
}

function bandLabel(band, tr, fmt) {
  var t = typeof tr === "function" ? tr : function(key, english) { return english }
  if (band === "auto") return t("network.bandAuto", "Auto")
  if (!band) return ""

                                                                         
                                    
  var number = Number(band)
  return (isFinite(number) ? formatter(fmt)(number) : band) + "ghz"
}

                                                                            
                                                                                
                                             
function bandSectionTitle(selected, current, tr, fmt) {
  var t = typeof tr === "function" ? tr : function(key, english) { return english }
  if (selected !== "auto") return t("network.wifiBand", "WI-FI BAND")

  var label = bandLabel(current, tr, fmt)
  if (label === "") return t("network.wifiBand", "WI-FI BAND")

  return t("network.wifiBandCurrent", "WI-FI BAND: %1").replace("%1", label.toUpperCase())
}

function bandTooltip(band, tr, fmt) {
  var t = typeof tr === "function" ? tr : function(key, english) { return english }
  if (band === "auto") return t("network.bandAutoTooltip", "Let Wi-Fi pick the band")
  if (!band) return ""
  return t("network.stayOnBand", "Stay on %1").replace("%1", bandLabel(band, tr, fmt))
}

function parseBandStatus(raw) {
  var next = parseKeyValue(raw)
  var tokens = String(next.available || "").split(" ")
  var available = []

  for (var i = 0; i < tokens.length; i++) {
    if (tokens[i] !== "") available.push(tokens[i])
  }

  return {
    band: next.band || "",
    selected: next.selected || "auto",
    available: available
  }
}

function formatter(fmt) {
  return typeof fmt === "function" ? fmt : function(v, d) { return d === undefined ? String(v) : Number(v).toFixed(d) }
}

function decodeIwSsid(value) {
  var raw = String(value || "")

  try {
    var encoded = ""

    for (var i = 0; i < raw.length; i++) {
      if (raw[i] === "\\" && raw[i + 1] === "x" && /^[0-9a-f]{2}$/i.test(raw.substring(i + 2, i + 4))) {
        var hex = raw.substring(i + 2, i + 4)
        var byte = parseInt(hex, 16)
        encoded += byte < 32 || byte === 127 ? encodeURIComponent(raw.substring(i, i + 4)) : "%" + hex
        i += 3
      } else {
        encoded += encodeURIComponent(raw[i])
      }
    }

    return decodeURIComponent(encoded)
  } catch (error) {
    return raw
  }
}

                                                                            
                                            
function parseKeyValue(raw) {
  var next = {}
  var lines = String(raw || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i]
    if (!line) continue
    var idx = line.indexOf("\t")
    if (idx === -1) continue
    var key = line.substring(0, idx)
    var value = line.substring(idx + 1)
    next[key] = key === "ssid" ? decodeIwSsid(value) : value.trim()
  }
  return next
}

function throughputState(previous, next, now) {
  var prev = previous || {}
  var sample = next || {}
  var iface = sample.iface || ""
  var rx = parseFloat(sample.rx_bytes || "0")
  var tx = parseFloat(sample.tx_bytes || "0")
  var previousTime = Number(prev.prevSampleTime || 0)

  if (iface !== (prev.prevIface || "") || previousTime === 0) {
    return {
      prevIface: iface,
      prevRxBytes: rx,
      prevTxBytes: tx,
      prevSampleTime: now,
      downloadRate: 0,
      uploadRate: 0
    }
  }

  var downloadRate = Number(prev.downloadRate || 0)
  var uploadRate = Number(prev.uploadRate || 0)
  var dt = now - previousTime
  if (dt > 0) {
    downloadRate = Math.max(0, (rx - Number(prev.prevRxBytes || 0)) / dt)
    uploadRate = Math.max(0, (tx - Number(prev.prevTxBytes || 0)) / dt)
  }

  return {
    prevIface: iface,
    prevRxBytes: rx,
    prevTxBytes: tx,
    prevSampleTime: now,
    downloadRate: downloadRate,
    uploadRate: uploadRate
  }
}

function pingSampleValue(raw) {
  var value = parseFloat(raw)
  if (!isFinite(value) || value < 0) return null
  return value
}

function appendPingSample(samples, raw, limit) {
  var values = Array.isArray(samples) ? samples.slice() : []

  values.push(pingSampleValue(raw))
  while (values.length > limit) values.shift()

  return values
}

function averagePingLatency(samples, limit) {
  var values = Array.isArray(samples) ? samples : []
  var sampleLimit = Math.max(1, parseInt(limit, 10) || values.length || 1)
  var total = 0
  var count = 0

  for (var i = Math.max(0, values.length - sampleLimit); i < values.length; i++) {
    var value = values[i]
    if (typeof value !== "number" || !isFinite(value) || value < 0) continue
    total += value
    count++
  }

  return count > 0 ? total / count : -1
}

function pingPacketLossPercent(samples) {
  var values = Array.isArray(samples) ? samples : []
  if (values.length === 0) return 0

  var lost = 0
  for (var i = 0; i < values.length; i++) {
    if (values[i] === null) lost++
  }

  return Math.round((lost / values.length) * 100)
}

                                                                             
                                                                             
                                                                 
function internetPingReadable(samples, connectivity) {
  var values = Array.isArray(samples) ? samples : []
  if (connectivity === "portal" || connectivity === "limited" || connectivity === "none") return false
  return values.length > 0
}

function formatPacketLoss(percent, hasSamples, fmt) {
  var f = formatter(fmt)
  if (hasSamples === false) return "--"

  var value = parseInt(percent, 10)
  if (!value || value < 0) return f(0) + "%"
  return f(value) + "%"
}

function pingLatencyState(previous, next, limit, averageLimit) {
  var prev = previous || {}
  var sample = next || {}
  var iface = sample.iface || ""
  var window = Math.max(1, parseInt(limit, 10) || 5)
  var averageWindow = Math.max(1, parseInt(averageLimit, 10) || window)
  var reset = iface === "" || iface !== (prev.pingIface || "")
  var routerSamples = reset ? [] : prev.routerPingSamples
  var internetSamples = reset ? [] : prev.internetPingSamples

  routerSamples = sample.router_ping_ms === undefined ? [] : appendPingSample(routerSamples, sample.router_ping_ms, window)
  internetSamples = sample.internet_ping_ms === undefined ? [] : appendPingSample(internetSamples, sample.internet_ping_ms, window)

  return {
    pingIface: iface,
    routerPingSamples: routerSamples,
    internetPingSamples: internetSamples,
    routerPingLatency: averagePingLatency(routerSamples, averageWindow),
    internetPingLatency: averagePingLatency(internetSamples, averageWindow),
    internetPingPacketLoss: pingPacketLossPercent(internetSamples)
  }
}

function formatBytes(bytes, fmt) {
  var f = formatter(fmt)
  var n = Number(bytes)
  if (!isFinite(n) || n < 0) n = 0
  if (n < 1024) return f(Math.round(n)) + " B"
  if (n < 1024 * 1024) return f(n / 1024, 1) + " KB"
  if (n < 1024 * 1024 * 1024) return f(n / (1024 * 1024), 1) + " MB"
  return f(n / (1024 * 1024 * 1024), 2) + " GB"
}

function formatRate(bytesPerSec, fmt) {
  return formatBytes(bytesPerSec, fmt) + "/s"
}

                                                                               
                                                                               
                                                             
function formatPingLatency(ms, hasSamples, tr, fmt) {
  var t = typeof tr === "function" ? tr : function(key, english) { return english }
  var f = formatter(fmt)
  if (hasSamples === false) return "--"

  var value = parseFloat(ms)
  if (!isFinite(value) || value < 0) return t("network.timeout", "Timeout")
  return f(value, value > 0 && value < 10 ? 1 : 0) + " ms"
}

function wifiRow(network) {
  if (!network) return null
                                                                               
                                                                                
                                                                          
                                                                            
                                                          
  return {
    connected: !!network.connected,
    known: !!network.known,
    ssid: network.name || "",
    signal: Math.round((network.signalStrength || 0) * 100),
    security: network.security
  }
}

function sortWifiRows(rows) {
  var nets = Array.isArray(rows) ? rows.slice() : []
  nets.sort(function(a, b) {
    if (a.connected !== b.connected) return a.connected ? -1 : 1
    if (a.known !== b.known) return a.known ? -1 : 1
    return b.signal - a.signal
  })
  return nets
}

function wifiSectionTitle(wifiNetworks, index, tr) {
  var t = typeof tr === "function" ? tr : function(key, english) { return english }
  var networks = Array.isArray(wifiNetworks) ? wifiNetworks : []
  if (index < 0 || index >= networks.length) return ""

  var net = networks[index]
  if (!net) return ""

  if (net.known && index === 0) return t("network.knownNetworks", "KNOWN NETWORKS")
  if (!net.known && (index === 0 || (networks[index - 1] && networks[index - 1].known))) return t("network.otherNetworks", "OTHER NETWORKS")
  return ""
}

                                                                              
                                                                            
                                                                          
function requiresCredentials(security, openSecurity, oweSecurity) {
                                                                               
                                               
  return security !== openSecurity && security !== oweSecurity
}

function canForgetNetwork(network) {
  return !!(network && network.known && !network.connected)
}

                                                                         
                                                                             
                                                                            
                   
var enterpriseConnectScript =
  "u=$(uuidgen); IFS= read -r pw;" +
  " nmcli connection add type wifi con-name \"$1\" ssid \"$1\" connection.uuid \"$u\"" +
  " wifi-sec.key-mgmt wpa-eap 802-1x.eap peap 802-1x.phase2-auth mschapv2" +
  " 802-1x.identity \"$2\" 802-1x.auth-timeout 8 >/dev/null" +
  " && printf 'set 802-1x.password %s\\nsave\\nquit\\n' \"$pw\" | nmcli connection edit uuid \"$u\" >/dev/null" +
  " && nmcli connection up uuid \"$u\"" +
  " || { nmcli connection delete uuid \"$u\" >/dev/null 2>&1; false; }"

function networkFailureReason(reason, needsCredentials, reasons, tr) {
  var t = typeof tr === "function" ? tr : function(key, english) { return english }
  var r = reasons || {}
  if (needsCredentials && reason === r.NoSecrets) return t("network.passphraseRequired", "Passphrase required")
  if (needsCredentials && reason === r.WifiAuthTimeout) return t("network.wrongPassword", "Wrong password")
  if (reason === r.WifiNetworkLost) return t("network.networkLost", "Network lost")
  if (reason === r.WifiClientDisconnected) return t("network.disconnected", "Disconnected")
  if (reason === r.WifiClientFailed) return t("network.connectionFailed", "Connection failed")
  return t("network.failedToConnect", "Failed to connect")
}

                                                                                
                                                                              
                                                                          
                                                                                
                                                                               
function shouldRepromptPassphrase(reason, needsCredentials, reasons) {
  var r = reasons || {}
  if (!needsCredentials) return false
  return reason === r.NoSecrets || reason === r.WifiAuthTimeout
}

                                                                              
                                                                                
                                     
function isValidIpv4(value) {
  var parts = String(value || "").trim().split(".")
  if (parts.length !== 4) return false
  for (var i = 0; i < 4; i++) {
    if (!/^\d{1,3}$/.test(parts[i])) return false
    var number = Number(parts[i])
    if (number < 0 || number > 255) return false
  }
  return true
}

function isValidIpv6(value) {
  var raw = String(value || "").trim()
  if (raw === "" || raw.indexOf(":") === -1) return false
  if (!/^[0-9a-fA-F:]+$/.test(raw)) return false
  var doubleColon = raw.indexOf("::")
  if (doubleColon !== -1 && raw.indexOf("::", doubleColon + 1) !== -1) return false
  var groups = raw.split("::")
  var filled = 0
  for (var i = 0; i < groups.length; i++) {
    if (groups[i] === "") continue
    var parts = groups[i].split(":")
    for (var j = 0; j < parts.length; j++) {
      if (!/^[0-9a-fA-F]{1,4}$/.test(parts[j])) return false
      filled++
    }
  }
  if (doubleColon === -1) return filled === 8
  return filled <= 7
}

                                                                           
                                                                        
function parseDnsServers(value) {
  var tokens = String(value || "").split(/[\s,]+/)
  var servers = []
  var invalid = []

  for (var i = 0; i < tokens.length; i++) {
    var token = tokens[i].trim()
    if (token === "") continue
    if (isValidIpv4(token) || isValidIpv6(token)) {
      if (servers.indexOf(token) === -1) servers.push(token)
    } else {
      invalid.push(token)
    }
  }

  return { servers: servers, invalid: invalid }
}

function classifyDns(servers, ignoreAuto) {
  var list = Array.isArray(servers) ? servers : String(servers || "").split(/[\s,]+/)
  var compact = []
  for (var i = 0; i < list.length; i++) {
    var token = String(list[i] || "").trim()
    if (token !== "") compact.push(token)
  }

                                                                         
                                                                        
  if (String(ignoreAuto || "").trim() !== "yes" || compact.length === 0) return "DHCP"

  var cloudflare = ["1.1.1.1", "1.0.0.1", "2606:4700:4700::1111", "2606:4700:4700::1001",
    "dns.cloudflare.com"]
  var google = ["8.8.8.8", "8.8.4.4", "2001:4860:4860::8888", "2001:4860:4860::8844",
    "dns.google"]

  var inCloudflare = true
  var inGoogle = true
  for (var c = 0; c < compact.length; c++) {
    if (cloudflare.indexOf(compact[c]) === -1) inCloudflare = false
    if (google.indexOf(compact[c]) === -1) inGoogle = false
  }
  if (inCloudflare) return "Cloudflare"
  if (inGoogle) return "Google"
  return "Custom"
}

                                                                              
                                                                             
function parseDnsStatus(raw) {
  var next = parseKeyValue(raw)
  var servers = String(next.servers || "").split(/[\s,]+/)
  var out = []
  for (var i = 0; i < servers.length; i++) {
    if (servers[i] !== "") out.push(servers[i])
  }
  return {
    provider: next.provider || "DHCP",
    servers: out
  }
}

                                                                                
                                                               
function parseQrOutput(raw) {
  var lines = String(raw || "").split(/\r?\n/)
  var meta = { iface: "", security: "", ssid: "" }
  var rows = []
  var size = 0

  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line === "") continue
    if (line.indexOf("meta\t") === 0) {
      var parts = line.split("\t")
      meta.iface = parts[1] || ""
      meta.security = parts[2] || ""
      meta.ssid = parts.slice(3).join("\t")
      continue
    }
    if (!/^[01]+$/.test(line)) continue
    if (size === 0) size = line.length
    rows.push(line.length >= size ? line.substring(0, size) : line + new Array(size - line.length + 1).join("0"))
  }

  return {
    iface: meta.iface,
    security: meta.security,
    ssid: meta.ssid,
    secured: meta.security !== "" && meta.security !== "nopass",
    rows: rows,
    size: size
  }
}

if (typeof module !== "undefined") {
  module.exports = {
    parseNetworkStatus: parseNetworkStatus,
    wifiIconFor: wifiIconFor,
    connectionIcon: connectionIcon,
    connectedSignalStrength: connectedSignalStrength,
    parseActiveApSignal: parseActiveApSignal,
    connectivityState: connectivityState,
    captivePortalUrl: captivePortalUrl,
    formatHeaderSpeed: formatHeaderSpeed,
    formatHeaderFreq: formatHeaderFreq,
    headerDetail: headerDetail,
    bandLabel: bandLabel,
    bandSectionTitle: bandSectionTitle,
    bandTooltip: bandTooltip,
    parseBandStatus: parseBandStatus,
    decodeIwSsid: decodeIwSsid,
    parseKeyValue: parseKeyValue,
    throughputState: throughputState,
    pingLatencyState: pingLatencyState,
    averagePingLatency: averagePingLatency,
    pingPacketLossPercent: pingPacketLossPercent,
    internetPingReadable: internetPingReadable,
    formatPacketLoss: formatPacketLoss,
    formatBytes: formatBytes,
    formatRate: formatRate,
    formatPingLatency: formatPingLatency,
    wifiRow: wifiRow,
    sortWifiRows: sortWifiRows,
    wifiSectionTitle: wifiSectionTitle,
    requiresCredentials: requiresCredentials,
    canForgetNetwork: canForgetNetwork,
    enterpriseConnectScript: enterpriseConnectScript,
    networkFailureReason: networkFailureReason,
    shouldRepromptPassphrase: shouldRepromptPassphrase,
    isValidIpv4: isValidIpv4,
    isValidIpv6: isValidIpv6,
    parseDnsServers: parseDnsServers,
    classifyDns: classifyDns,
    parseDnsStatus: parseDnsStatus,
    parseQrOutput: parseQrOutput
  }
}
