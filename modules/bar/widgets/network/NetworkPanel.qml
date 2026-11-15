import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.common
import qs.config
import "Model.js" as Model









PanelShell {
  id: root

  layerNamespace: "omashell-network"
                                                                             
                                                                             
  cardWidth: root.width > 0 ? Math.min(380, Math.max(120, root.width - Constants.gap * 2)) : 380
  spacing: 12
  keyboard: true
  focusTarget: nav

  signal switchPanelRequested(int direction)
  signal shareRequested(string payload)
  signal speedTestRequested(string payload)

  readonly property string scriptDir: String(Qt.resolvedUrl("scripts")).replace("file://", "")

  function scriptPath(name) {
    return root.scriptDir + "/" + name
  }

                                                                                 

  readonly property bool networkManagerAvailable: Networking.backend === NetworkBackendType.NetworkManager
  readonly property var networkDevices: Networking.devices ? Networking.devices.values : []
  readonly property var wiredDevice: findDevice(DeviceType.Wired)
  readonly property var wifiDevice: findDevice(DeviceType.Wifi)
  readonly property var wifiNetworkObjects: wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []
  readonly property var connectedWifiNetwork: findConnectedWifiNetwork()

                                                                            
  readonly property string kind: {
    if (root.wiredDevice && root.wiredDevice.connected) return "ethernet"
    if (root.connectedWifiNetwork) return "wifi"
                                                                      
                                                                           
                                                                              
                                                                          
    if (root.wifiDevice && root.wifiDevice.connected) return "wifi"
    return "disconnected"
  }

  property int activeApSignal: -1
  readonly property bool needsActiveApSignal: root.kind === "wifi"
    && !(root.connectedWifiNetwork && root.connectedWifiNetwork.signalStrength > 0)
  readonly property int signalStrength: root.kind === "wifi"
    ? Model.connectedSignalStrength(root.connectedWifiNetwork ? root.connectedWifiNetwork.signalStrength : 0,
        root.activeApSignal)
    : -1

  readonly property bool connectivityChecksEnabled: root.networkManagerAvailable
    && Networking.canCheckConnectivity && Networking.connectivityCheckEnabled
  readonly property string connectivity: Model.connectivityState(root.kind, Networking.connectivity, {
    Portal: NetworkConnectivity.Portal,
    Limited: NetworkConnectivity.Limited,
    Full: NetworkConnectivity.Full,
    None: NetworkConnectivity.None
  }, root.connectivityChecksEnabled)
  readonly property bool hasCaptivePortal: root.connectivity === "portal"
  readonly property bool restricted: root.hasCaptivePortal || root.connectivity === "limited"
  readonly property string icon: Model.connectionIcon(root.kind, root.signalStrength, root.connectivity)

                                                                              
                                                      
  readonly property string connectionKey: root.kind === "wifi" && root.wifiDevice
    ? root.kind + ":" + root.wifiDevice.name
    : (root.kind === "ethernet" && root.wiredDevice ? root.kind + ":" + root.wiredDevice.name : "")

  onConnectionKeyChanged: Qt.callLater(root.checkConnectivity)
  onConnectivityChecksEnabledChanged: Qt.callLater(root.checkConnectivity)

  readonly property string heroTitle: {
    if (root.kind === "ethernet") return "Ethernet"
    if (root.kind === "wifi") {
      var net = root.connectedWifiNetwork
      if (net && net.name) return net.name
      return root.wifiDevice ? root.wifiDevice.name : "Wi-Fi"
    }
    return "Disconnected"
  }

  readonly property string heroDetail: {
    if (root.kind === "ethernet") return Model.headerDetail(root.info, null)
    return ""
  }

  readonly property var connectionPhrases: [
    "Wiring bits",
    "Routing packets",
    "Link alive",
    "Finding a signal",
    "Surfing the web"
  ]
  readonly property string stateText: {
    if (root.kind === "disconnected") return "Not connected"
    if (root.hasCaptivePortal) return "Sign-in required"
    if (root.restricted) return "Limited access"
    return root.connectionPhrases[root.phraseIndex % root.connectionPhrases.length]
  }
  property int phraseIndex: 0

  Timer {
    interval: 2800
    repeat: true
    running: root.opened && !root.restricted && root.kind !== "disconnected"
    onTriggered: root.phraseIndex = (root.phraseIndex + 1) % root.connectionPhrases.length
  }

                                                                                

  property var info: ({})
  property real prevRxBytes: 0
  property real prevTxBytes: 0
  property real prevSampleTime: 0
  property string prevIface: ""
  property real downloadRate: 0
  property real uploadRate: 0
  property string pingIface: ""
  property var routerPingSamples: []
  property var internetPingSamples: []
  property real routerPingLatency: -1
  property real internetPingLatency: -1
  property int internetPingPacketLoss: 0
  readonly property int pingHistoryWindow: 24
  readonly property int pingAverageWindow: 5
  readonly property bool hasInternetPing: Model.internetPingReadable(root.internetPingSamples, root.connectivity)
  readonly property bool hasTransferStats: root.info.rx_bytes !== undefined

  readonly property var detailCells: {
    var cells = [
      { label: "Ping", value: root.formatPing(root.internetPingLatency), copy: "" },
      { label: "Packet Loss", value: root.formatLoss(root.internetPingPacketLoss), copy: "" },
      { label: "Receiving", value: root.hasTransferStats ? Model.formatRate(root.downloadRate) : "--", copy: "" },
      { label: "Sending", value: root.hasTransferStats ? Model.formatRate(root.uploadRate) : "--", copy: "" },
      { label: "Downloaded", value: root.hasTransferStats ? Model.formatBytes(parseFloat(root.info.rx_bytes || "0")) : "--", copy: "" },
      { label: "Uploaded", value: root.hasTransferStats ? Model.formatBytes(parseFloat(root.info.tx_bytes || "0")) : "--", copy: "" },
      { label: "IP Address", value: root.info.ip || "--", copy: root.info.ip || "" },
      { label: "Gateway", value: root.info.gateway || "--", copy: root.info.gateway || "" }
    ]
    return cells
  }

  function formatPing(ms) {
    return Model.formatPingLatency(ms, root.hasInternetPing)
  }

  function formatLoss(percent) {
    return Model.formatPacketLoss(percent, root.hasInternetPing)
  }

  function updateDetails(raw) {
    var parsed = Model.parseKeyValue(raw)
    root.info = parsed

    var now = Date.now() / 1000
    var throughput = Model.throughputState({
      prevIface: root.prevIface,
      prevRxBytes: root.prevRxBytes,
      prevTxBytes: root.prevTxBytes,
      prevSampleTime: root.prevSampleTime,
      downloadRate: root.downloadRate,
      uploadRate: root.uploadRate
    }, parsed, now)
    root.prevIface = throughput.prevIface
    root.prevRxBytes = throughput.prevRxBytes
    root.prevTxBytes = throughput.prevTxBytes
    root.prevSampleTime = throughput.prevSampleTime
    root.downloadRate = throughput.downloadRate
    root.uploadRate = throughput.uploadRate

    var ping = Model.pingLatencyState({
      pingIface: root.pingIface,
      routerPingSamples: root.routerPingSamples,
      internetPingSamples: root.internetPingSamples
    }, parsed, root.pingHistoryWindow, root.pingAverageWindow)
    root.pingIface = ping.pingIface
    root.routerPingSamples = ping.routerPingSamples
    root.internetPingSamples = ping.internetPingSamples
    root.routerPingLatency = ping.routerPingLatency
    root.internetPingLatency = ping.internetPingLatency
    root.internetPingPacketLoss = ping.internetPingPacketLoss
  }

  function pollDetails() {
    if (detailsProc.running) return
    detailsProc.running = true
  }

  function resetDetails() {
    root.info = ({})
    root.prevIface = ""
    root.prevRxBytes = 0
    root.prevTxBytes = 0
    root.prevSampleTime = 0
    root.downloadRate = 0
    root.uploadRate = 0
    root.pingIface = ""
    root.routerPingSamples = []
    root.internetPingSamples = []
    root.routerPingLatency = -1
    root.internetPingLatency = -1
    root.internetPingPacketLoss = 0
  }

  Process {
    id: detailsProc

    command: ["bash", root.scriptPath("network-status.sh"), "--verbose"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateDetails(text)
    }
  }

  Timer {
    id: detailsPoll

    interval: 1500
    repeat: true
    running: root.opened
    onTriggered: root.pollDetails()
  }

                                                                                

  function checkConnectivity() {
    if (!root.connectivityChecksEnabled || root.kind === "disconnected") return
    Networking.checkConnectivity()
  }

  function openCaptivePortal() {
    Qt.openUrlExternally(Model.captivePortalUrl)
  }

                                                                                

  property bool scanning: false
  readonly property bool canToggleWifi: root.networkManagerAvailable && root.wifiDevice !== null

  function startScan() {
    if (!root.wifiDevice) return
    root.wifiDevice.scannerEnabled = true
    root.scanning = true
    scanDone.restart()
  }

  Timer {
    id: scanDone

    interval: 2000
    repeat: false
    onTriggered: {
      root.scanning = false
      root.syncWifiNetworks()
    }
  }

                                                                                

  property var wifiNetworks: []
  property bool wifiStationAvailable: false

  function findDevice(type) {
    var devices = root.networkDevices || []
    var fallback = null
    for (var i = 0; i < devices.length; i++) {
      var device = devices[i]
      if (!device || device.type !== type) continue
      if (device.connected) return device
      if (!fallback) fallback = device
    }
    return fallback
  }

  function findConnectedWifiNetwork() {
    var networks = root.wifiNetworkObjects || []
    for (var i = 0; i < networks.length; i++) {
      if (networks[i] && networks[i].connected) return networks[i]
    }
    return null
  }

  function networkForSsid(ssid) {
    var networks = root.wifiNetworkObjects || []
    for (var i = 0; i < networks.length; i++) {
      if (networks[i] && networks[i].name === ssid) return networks[i]
    }
    return null
  }

  function syncWifiNetworks() {
    var rows = []
    var networks = root.wifiNetworkObjects || []
    for (var i = 0; i < networks.length; i++) {
      var network = networks[i]
      if (!network) continue
      root.checkActionCompletion(network)
      var row = Model.wifiRow(network)
      if (row) rows.push(row)
    }
                                                                        
                                                                        
    if (root.passwordSsid === "") {
      var sorted = Model.sortWifiRows(rows)
      if (JSON.stringify(sorted) !== JSON.stringify(root.wifiNetworks)) root.wifiNetworks = sorted
    }
    root.wifiStationAvailable = root.wifiDevice !== null
  }

  onWifiNetworkObjectsChanged: Qt.callLater(root.syncWifiNetworks)
  onWifiNetworksChanged: if (root.opened) Qt.callLater(nav.refresh)
  Component.onCompleted: root.syncWifiNetworks()

  function wifiSectionTitle(index) {
    return Model.wifiSectionTitle(root.wifiNetworks, index)
  }

  function rowForSsid(ssid) {
    for (var i = 0; i < root.wifiNetworks.length; i++) {
      if (root.wifiNetworks[i] && root.wifiNetworks[i].ssid === ssid) return root.wifiNetworks[i]
    }
    return null
  }

  function requiresCredentials(row) {
    return Model.requiresCredentials(row ? row.security : 0, WifiSecurityType.Open, WifiSecurityType.Owe)
  }

  function isEnterprise(row) {
    if (!row) return false
    return row.security === WifiSecurityType.Wpa2Eap || row.security === WifiSecurityType.WpaEap
  }

  function canShare(row) {
    if (!row || !row.connected) return false
    return !root.isEnterprise(row)
  }

  readonly property bool canShareWifi: !!root.connectedWifiNetwork
    && !root.isEnterprise({ security: root.connectedWifiNetwork.security })

                                                                                

  property string actionSsid: ""
  property string actionKind: ""                                        
  property string failureSsid: ""
  property string failureReason: ""
  readonly property bool busy: root.actionKind !== ""

  readonly property var connectionFailReasons: ({
    NoSecrets: ConnectionFailReason.NoSecrets,
    WifiAuthTimeout: ConnectionFailReason.WifiAuthTimeout,
    WifiNetworkLost: ConnectionFailReason.WifiNetworkLost,
    WifiClientDisconnected: ConnectionFailReason.WifiClientDisconnected,
    WifiClientFailed: ConnectionFailReason.WifiClientFailed
  })

  function networkFailureReason(reason, needsCredentials) {
    return Model.networkFailureReason(reason, needsCredentials, root.connectionFailReasons)
  }

  function clearNetworkAction() {
    actionTimeout.stop()
    root.actionSsid = ""
    root.actionKind = ""
    root.failureSsid = ""
    root.failureReason = ""
    root.passwordSsid = ""
    root.passwordText = ""
    root.identityText = ""
    root.syncWifiNetworks()
    root.pollDetails()
  }

  function runNetworkAction(actionKind, network, callback) {
    if (root.actionKind !== "" || !network) return
    root.actionSsid = network.name || ""
    root.actionKind = actionKind
    root.failureSsid = ""
    root.failureReason = ""
    actionTimeout.stop()
    callback(network)
    actionTimeout.restart()
  }

  function checkActionCompletion(network) {
    if (!network || root.actionKind === "" || root.actionSsid !== (network.name || "")) return
    if (root.actionKind === "connect" && network.connected) root.clearNetworkAction()
    else if (root.actionKind === "disconnect" && !network.connected && !network.stateChanging) root.clearNetworkAction()
    else if (root.actionKind === "forget" && !network.known && !network.stateChanging) root.clearNetworkAction()
  }

  function failNetworkAction(network, reason) {
    if (!network || root.actionKind === "" || root.actionSsid !== (network.name || "")) return
    actionTimeout.stop()
    root.failureSsid = root.actionSsid
    root.failureReason = root.networkFailureReason(reason, root.requiresCredentials(root.rowForSsid(root.actionSsid)))
    root.actionSsid = ""
    root.actionKind = ""
    root.syncWifiNetworks()
  }

                                                                            
                                                                            
                                                  

  Timer {
    id: actionTimeout

                                                                              
                                                                             
                                                            
    interval: 30000
    repeat: false
    onTriggered: {
      if (root.actionKind === "") return
      root.failureSsid = root.actionSsid
      root.failureReason = "Timed out"
      root.actionSsid = ""
      root.actionKind = ""
      root.syncWifiNetworks()
    }
  }

  function activateRow(row) {
    if (!row || root.busy) return
    if (row.connected) {
      root.disconnectRow(row.ssid)
      return
    }
    if (root.requiresCredentials(row) && !row.known) {
      root.openPasswordPrompt(row.ssid)
      return
    }
    root.connectDirectly(row.ssid)
  }

  function connectDirectly(ssid) {
    root.runNetworkAction("connect", root.networkForSsid(ssid), function(network) { network.connect() })
  }

  function connectWithPassphrase(ssid, passphrase) {
    root.runNetworkAction("connect", root.networkForSsid(ssid), function(network) {
      network.connectWithPsk(passphrase)
    })
    root.passwordText = ""
  }

  function connectEnterprise(ssid, identity, passphrase) {
    root.runNetworkAction("connect", root.networkForSsid(ssid), function() {
      enterpriseConnect.secret = passphrase
      enterpriseConnect.command = ["bash", "-c", Model.enterpriseConnectScript, "omashell-eap", ssid, identity]
      enterpriseConnect.running = true
    })
    root.passwordText = ""
    root.identityText = ""
  }

                                              
  Process {
    id: enterpriseConnect

    property string secret: ""
    stdinEnabled: true
    onStarted: {
      write(enterpriseConnect.secret + "\n")
      enterpriseConnect.secret = ""
    }
  }

  function disconnectRow(ssid) {
    var network = root.networkForSsid(ssid)
    if (!network) return
    root.runNetworkAction("disconnect", network, function(net) { net.disconnect() })
  }

  function forgetRow(row) {
    if (!row) return
    var network = root.networkForSsid(row.ssid)
    if (!network) return
    root.runNetworkAction("forget", network, function(net) { net.forget() })
  }

  property string passwordSsid: ""
  onPasswordSsidChanged: if (passwordSsid === "" && root.opened)
    Qt.callLater(function() { if (root.opened) nav.takeFocus() })
  property string passwordText: ""
  property string identityText: ""

  function openPasswordPrompt(ssid) {
    if (root.passwordSsid === ssid) return
    root.passwordText = ""
    root.identityText = ""
    root.passwordSsid = ssid
    Qt.callLater(root.resetNavigation)
  }

  function cancelPasswordPrompt() {
    root.passwordSsid = ""
    root.passwordText = ""
    root.identityText = ""
  }

  function submitCredentials(ssid, passphrase, identity, enterprise) {
    if (passphrase.length === 0) return
    if (enterprise) {
      if (identity.length === 0) return
      root.connectEnterprise(ssid, identity, passphrase)
    } else {
      root.connectWithPassphrase(ssid, passphrase)
    }
  }

                                                                                

  property string bandCurrent: ""
  property string bandSelected: "auto"
  property var bandAvailable: []
  property string pendingBand: ""
  readonly property string bandEffective: root.pendingBand !== "" ? root.pendingBand : root.bandSelected
  readonly property bool bandPinned: root.bandEffective !== "auto"
  readonly property bool canSelectBand: root.wifiDevice !== null
    && (root.kind === "wifi" || root.bandBusy)
    && (root.bandAvailable.length > 1 || root.bandPinned)
  readonly property bool bandPillsVisible: root.canSelectBand && root.bandPinned
  readonly property string bandSectionTitle: Model.bandSectionTitle(root.bandEffective, root.bandCurrent)
  readonly property bool bandBusy: root.pendingBand !== ""

  function updateBand(raw) {
    var status = Model.parseBandStatus(raw)
                                                                         
                                                                           
                               
    if (root.bandBusy && status.available.length === 0) return
    root.bandCurrent = status.band
    root.bandSelected = status.selected
    root.bandAvailable = status.available
  }

  function refreshBand() {
    if (bandQuery.running) return
    bandQuery.running = true
  }

  function setBand(band) {
    if (!band || bandProc.running) return
    root.pendingBand = band
    bandProc.command = ["bash", root.scriptPath("network-band.sh"), band]
    bandProc.running = true
  }

  Process {
    id: bandQuery

    command: ["bash", root.scriptPath("network-band.sh")]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateBand(text)
    }
  }

  Process {
    id: bandProc

    stderr: StdioCollector {
      id: bandStderr
      waitForEnd: true
    }

    onExited: function(exitCode) {
      var requested = root.pendingBand
      root.pendingBand = ""
      if (exitCode === 0) root.bandSelected = requested
      root.refreshBand()
      root.pollDetails()
    }
  }

  Timer {
    interval: 4000
    repeat: true
    running: root.opened && root.kind === "wifi"
    onTriggered: root.refreshBand()
  }

  FontMetrics {
    id: dnsFontMetrics
    font.family: Constants.fontFamily
    font.pixelSize: Constants.fontBodySmall
  }

                                                                                

  property string dnsProvider: "DHCP"
  property string pendingDnsProvider: ""
  property var dnsServers: []
  property string dnsCustomText: ""
  property bool editingCustomDns: false
  property string dnsError: ""
  readonly property string dnsEffective: root.pendingDnsProvider !== "" ? root.pendingDnsProvider : root.dnsProvider
  readonly property var dnsProviders: ["DHCP", "Cloudflare", "Google", "Custom"]
  readonly property bool canSetDns: root.networkManagerAvailable && root.kind !== "disconnected"

  function updateDns(raw) {
    var status = Model.parseDnsStatus(raw)
    root.dnsProvider = status.provider
    root.dnsServers = status.servers
    if (status.provider === "Custom" || root.dnsCustomText === "") {
      root.dnsCustomText = status.servers.join(", ")
    }
  }

  function refreshDns() {
    if (!root.canSetDns || dnsQuery.running) return
    dnsQuery.running = true
  }

  function setDns(provider, servers) {
    if (!provider || dnsProc.running) return
    root.dnsError = ""

    if (provider === "Custom" && servers === undefined) {
      root.editingCustomDns = true
      return
    }
    root.editingCustomDns = false
    if (provider === "Custom") {
      var parsed = Model.parseDnsServers(servers !== undefined ? servers : root.dnsCustomText)
      if (parsed.invalid.length > 0) {
        root.dnsError = "Not a valid address: " + parsed.invalid.join(", ")
        return
      }
      if (parsed.servers.length === 0) {
        root.dnsError = "Enter at least one DNS server."
        return
      }
      root.pendingDnsProvider = provider
      dnsProc.command = ["bash", root.scriptPath("network-dns.sh"), provider, parsed.servers.join(",")]
    } else {
      root.pendingDnsProvider = provider
      dnsProc.command = ["bash", root.scriptPath("network-dns.sh"), provider]
    }

    dnsProc.running = true
  }

  Process {
    id: dnsQuery

    command: ["bash", root.scriptPath("network-dns.sh")]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.updateDns(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.dnsError = "Could not read the current DNS provider."
    }
  }

  Process {
    id: dnsProc

    stderr: StdioCollector {
      id: dnsErrorText
      waitForEnd: true
    }

    onExited: function(exitCode) {
      var requested = root.pendingDnsProvider
      root.pendingDnsProvider = ""
      if (exitCode === 0) {
        root.dnsProvider = requested
        root.dnsError = ""
      } else {
        var detail = String(dnsErrorText.text || "").trim()
        root.dnsError = detail !== "" ? detail : "DNS change failed (permission or profile problem)."
      }
      root.refreshDns()
      root.pollDetails()
    }
  }

                                                                                

  function shareWifi() {
    if (!root.connectedWifiNetwork || !root.canShareWifi) return
    root.close()
    root.cancelPasswordPrompt()
    root.shareRequested(JSON.stringify({
      iface: root.wifiDevice ? root.wifiDevice.name : "",
      ssid: root.connectedWifiNetwork.name || ""
    }))
  }

  function summonSpeedTest() {
    var connection = root.kind === "ethernet" ? "Ethernet" : root.heroTitle
    root.close()
    root.speedTestRequested(JSON.stringify({ connection: connection }))
  }

                                                                                

  property var navigationPositions: ({})

  function groupItems(group) {
    return nav.items.filter(function(item) { return item.navGroup === group })
  }

  function selectGroup(group, position) {
    var items = root.groupItems(group)
    if (!items.length) return false
    var index = Math.max(0, Math.min(items.length - 1, position || 0))
    nav.select(items[index])
    return true
  }

  function resetNavigation() {
    nav.refresh()
    root.navigationPositions = ({ dns: Math.max(0, root.dnsProviders.indexOf(root.dnsProvider)) })
    var start = root.groupItems(root.hasCaptivePortal ? "portal" : "wifi")
    if (!start.length) {
      start = root.groupItems("dns")
      var dnsIndex = root.navigationPositions.dns
      if (start.length && dnsIndex < start.length) start = [start[dnsIndex]]
    }
    nav.reset(start.length ? Math.max(0, nav.items.indexOf(start[0])) : 0)
    if (root.hasCaptivePortal && start.length) nav.select(start[0])
  }

  function moveNetworkCursor(dx, dy) {
    nav.refresh()
    if (!nav.current) return
    if (!nav.cursorActive) {
      nav.cursorActive = true
      nav.sync()
      if (dy >= 0) return
    }
    var group = nav.current.navGroup || ""
    var groupList = root.groupItems(group)
    var index = groupList.indexOf(nav.current)
    if (dx !== 0) {
      if (group === "wifi") { nav.current.adjust(dx); return }
      if (group === "header" || group === "dns" || group === "band")
        root.selectGroup(group, Math.max(0, Math.min(groupList.length - 1, index + dx)))
      return
    }
    if (dy === 0) return
    if (group === "wifi" && ((dy < 0 && index > 0) || (dy > 0 && index < groupList.length - 1))) {
      root.selectGroup("wifi", index + dy)
      return
    }
    var positions = Object.assign({}, root.navigationPositions)
    positions[group] = Math.max(0, index)
    root.navigationPositions = positions
    var groups = ["header", "portal", "bandAuto", "band", "dns", "wifi"]
    var at = groups.indexOf(group)
    if (at < 0) return
    for (var i = at + dy; i >= 0 && i < groups.length; i += dy) {
      var candidate = groups[i]
      var desired = candidate === "wifi" ? 0 : (positions[candidate] || 0)
      if (root.selectGroup(candidate, desired)) return
    }
  }

  function ensureCurrentVisible() {
    var current = nav.current
    if (!current || current.isWifiRow !== true || sectionViewport.height <= 0) return
    var y = current.mapToItem(sectionViewport, 0, 0).y
    if (y < 0) sectionViewport.contentY = Math.max(0, sectionViewport.contentY + y)
    else if (y + current.height > sectionViewport.height)
      sectionViewport.contentY = Math.min(sectionViewport.contentHeight - sectionViewport.height,
        sectionViewport.contentY + y + current.height - sectionViewport.height)
  }

  onOpenedChanged: {
    if (root.opened) {
      root.dnsError = ""
      root.resetDetails()
      root.pollDetails()
      root.syncWifiNetworks()
      root.refreshDns()
      root.refreshBand()
      Qt.callLater(root.startScan)
      Qt.callLater(root.resetNavigation)
    } else {
      root.cancelPasswordPrompt()
      root.dnsError = ""
      if (root.wifiDevice) root.wifiDevice.scannerEnabled = false
    }
  }

                                                                                

  Column {
    id: body

    width: parent.width
    spacing: 12

    PanelHeader {
      width: parent.width
      panelNav: nav
      icon: root.icon
      title: root.heroTitle + (root.heroDetail !== "" ? " (" + root.heroDetail + ")" : "")
      captions: [root.stateText]
      rotating: false
      switchVisible: root.canToggleWifi
      switchChecked: Networking.wifiEnabled
      switchNavigationKey: "network-wifi-switch"
      switchNavGroup: "header"
      switchOnTooltip: "Turn Wi-Fi on"
      switchOffTooltip: "Turn Wi-Fi off"
      foreground: root.restricted ? Colors.red : Colors.foreground

      onSwitchToggled: Networking.wifiEnabled = !Networking.wifiEnabled

      ActionIcon {
        visible: root.canShareWifi
        glyph: "\u{f0432}"
        tooltipText: "Share Wi-Fi"
        navGroup: "header"
        panelNav: nav
        onActivated: root.shareWifi()
      }

      ActionIcon {
        visible: root.kind !== "disconnected"
        glyph: "\u{f04c5}"
        tooltipText: "Run speed test"
        navGroup: "header"
        panelNav: nav
        onActivated: root.summonSpeedTest()
      }

    }

    Button {
      visible: root.hasCaptivePortal
      width: parent.width
      text: "Open captive portal"
      navGroup: "portal"
      panelNav: nav
      accented: true
      onActivated: root.openCaptivePortal()
    }

    Text {
      visible: root.restricted && !root.hasCaptivePortal
      width: parent.width
      text: "This network has limited internet access."
      color: Colors.yellow
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontBodySmall
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      wrapMode: Text.WordWrap
    }

    Grid {
      id: detailsGrid
      visible: !!root.info.iface

      width: parent.width
      columns: 2
      columnSpacing: 14
      rowSpacing: 3

      Repeater {
                                                                        
                                                                              
        model: 8

        delegate: Item {
          id: detailCell

          required property int index
          readonly property var modelData: root.detailCells[index]

          width: (detailsGrid.width - detailsGrid.columnSpacing) / 2
          implicitHeight: Math.max(detailLabel.implicitHeight, detailValue.implicitHeight)

          function copy() {
            if (detailCell.modelData.copy === "") return
            Quickshell.clipboardText = String(detailCell.modelData.copy)
          }

          Text {
            id: detailLabel
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: detailCell.modelData.label
            color: Qt.darker(Colors.foreground, 1.4)
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontBodySmall
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
          }

          Text {
            id: detailValue
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - detailLabel.implicitWidth - 8)
            horizontalAlignment: Text.AlignRight
            text: detailCell.modelData.value
            color: Colors.foreground
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontBodySmall
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            elide: Text.ElideRight
          }

          MouseArea {
            anchors.fill: detailValue
            hoverEnabled: true
            enabled: detailCell.modelData.copy !== ""
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: detailCell.copy()

            PanelToolTip {
              visible: parent.containsMouse && detailCell.modelData.copy !== ""
              text: detailCell.index === 6 ? "Copy IP address" : "Copy gateway"
              fontFamily: Constants.fontFamily
            }
          }
        }
      }
    }

    PanelSeparator {
      width: parent.width
      pixelRatio: root.devicePixelRatio
    }

    Column {
      width: parent.width
      spacing: 8
      visible: root.canSelectBand

      Row {
        width: parent.width
        spacing: 8

        SectionLabel {
          width: parent.width - autoSwitch.width - parent.spacing
          text: root.bandSectionTitle
          anchors.verticalCenter: parent.verticalCenter
        }

        ToggleSwitch {
          id: autoSwitch
          anchors.verticalCenter: parent.verticalCenter
          checked: root.bandEffective === "auto"
          panelNav: nav
          navigationKey: "network-band-auto"
          navGroup: "bandAuto"
          onToggled: root.setBand(root.bandPinned ? "auto" : root.bandCurrent)

          PanelToolTip {
            visible: parent.containsMouse
            text: Model.bandTooltip(root.bandEffective)
            fontFamily: Constants.fontFamily
          }
        }
      }

      Row {
        id: bandRow

        width: parent.width
        spacing: 6
        visible: root.bandPillsVisible

        Repeater {
          model: root.bandPillsVisible ? root.bandAvailable : []

          delegate: Button {
            required property string modelData

            width: (bandRow.width - (root.bandAvailable.length - 1) * bandRow.spacing) / Math.max(1, root.bandAvailable.length)
            height: 26
            text: Model.bandLabel(modelData)
            navGroup: "band"
            panelNav: nav
            accented: root.bandEffective === modelData
            onActivated: root.setBand(modelData)
          }
        }
      }
    }

    PanelSeparator {
      width: parent.width
      pixelRatio: root.devicePixelRatio
      visible: root.canSelectBand
    }

    Column {
      width: parent.width
      spacing: 8
      visible: root.canSetDns

      SectionLabel {
        width: parent.width
        text: "DNS PROVIDER"
      }

      Row {
        id: dnsRow

        width: parent.width
        spacing: 6

        Repeater {
          model: root.dnsProviders

          delegate: Button {
            required property string modelData

            width: (dnsRow.width - (root.dnsProviders.length - 1) * dnsRow.spacing) / root.dnsProviders.length
            height: Math.ceil(dnsFontMetrics.height) + 18
            text: modelData
            navGroup: "dns"
            panelNav: nav
            fontSize: Constants.fontBodySmall
            outlined: true
            referenceStates: true
            selected: root.dnsEffective === modelData
            onActivated: root.setDns(modelData)

            PanelToolTip {
              visible: parent.containsMouse
              text: (modelData === "DHCP" ? "Use automatic DNS" : "Set DNS to " + modelData)
                + " for the active connection"
              fontFamily: Constants.fontFamily
            }
          }
        }
      }

      Field {
        width: parent.width
        visible: root.editingCustomDns
        placeholder: "1.1.1.1, 8.8.8.8"
        text: root.dnsCustomText
        onTextChanged: root.dnsCustomText = text
        onSubmitted: root.setDns("Custom", text)
      }

      Text {
        width: parent.width
        visible: root.dnsError !== ""
        text: root.dnsError
        color: Colors.red
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontCaption
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        wrapMode: Text.WordWrap
      }

    }

    PanelSeparator {
      width: parent.width
      pixelRatio: root.devicePixelRatio
    }

    Text {
      visible: root.wifiDevice === null
      width: parent.width
      text: root.networkManagerAvailable ? "No Wi-Fi adapter" : "NetworkManager is not available"
      color: Colors.darkForeground
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontBodySmall
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      wrapMode: Text.WordWrap
    }

    Text {
      visible: root.wifiDevice !== null && root.wifiNetworks.length === 0
      width: parent.width
      text: root.scanning ? "Scanning…" : "No networks in range"
      color: Colors.darkForeground
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontBodySmall
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
    }

    Flickable {
      id: sectionViewport

      width: parent.width
      height: Math.min(networkList.implicitHeight, 240)
      contentHeight: networkList.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height
      visible: root.wifiDevice !== null && root.wifiNetworks.length > 0

      Column {
        id: networkList

        width: sectionViewport.width
        spacing: 4

        Repeater {
          model: root.wifiNetworks

          delegate: Column {
            id: rowDelegate

            required property var modelData
            required property int index

            readonly property string sectionTitle: root.wifiSectionTitle(rowDelegate.index)

            width: networkList.width
            spacing: 4

            SectionLabel {
              width: parent.width
              visible: rowDelegate.sectionTitle !== ""
              height: visible ? implicitHeight : 0
              text: rowDelegate.sectionTitle
            }

            WifiRow {
              width: rowDelegate.width
              row: rowDelegate.modelData
              navGroup: "wifi"
              network: root.networkForSsid(rowDelegate.modelData.ssid)
              enterprise: root.isEnterprise(rowDelegate.modelData)
              credentialsRequired: root.requiresCredentials(rowDelegate.modelData)
              pendingKind: root.actionKind !== "" && root.actionSsid === rowDelegate.modelData.ssid
                ? root.actionKind : ""
              failureReason: root.failureSsid === rowDelegate.modelData.ssid ? root.failureReason : ""
              passwordOpen: root.passwordSsid !== "" && root.passwordSsid === rowDelegate.modelData.ssid
              panelNav: nav

              onActivated: {
                if (root.passwordSsid === rowDelegate.modelData.ssid && root.failureReason !== "") {
                  root.failureReason = ""
                  root.failureSsid = ""
                } else root.activateRow(rowDelegate.modelData)
              }
              onPasswordCanceled: { root.cancelPasswordPrompt(); nav.takeFocus(); root.syncWifiNetworks() }
              onForgetRequested: root.forgetRow(rowDelegate.modelData)
              onCredentialsSubmitted: function(passphrase, identity) {
                root.submitCredentials(rowDelegate.modelData.ssid, passphrase, identity,
                  root.isEnterprise(rowDelegate.modelData))
              }
            }

            Connections {
              target: root.networkForSsid(rowDelegate.modelData.ssid)
              ignoreUnknownSignals: true

              function onConnectionFailed(reason) {
                var ours = root.actionKind === "connect" && root.actionSsid === (rowDelegate.modelData.ssid || "")
                root.failNetworkAction(root.networkForSsid(rowDelegate.modelData.ssid), reason)
                if (ours && Model.shouldRepromptPassphrase(reason,
                    root.requiresCredentials(rowDelegate.modelData), root.connectionFailReasons))
                  root.openPasswordPrompt(rowDelegate.modelData.ssid)
              }
            }
          }
        }
      }
    }
  }

                                                                         
                                                                               
                                                     
  Timer {
    interval: 2000
    repeat: true
    running: root.opened && root.wifiDevice !== null
    onTriggered: root.syncWifiNetworks()
  }

  PanelNav {
    id: nav

    container: body
    customNavigation: true
    onMoveRequested: function(dx, dy) { root.moveNetworkCursor(dx, dy) }
    onCanceled: root.close()
    onTabRequested: function(direction) { root.switchPanelRequested(direction) }
    onDeleteRequested: {
      if (nav.current && nav.current.isWifiRow === true) nav.current.forget()
    }
    onTextRequested: function(text) {
      if (text === "r" || text === "R") { root.startScan(); root.pollDetails(); root.refreshDns(); root.refreshBand() }
      else if ((text === "w" || text === "W") && root.canToggleWifi) Networking.wifiEnabled = !Networking.wifiEnabled
    }
    onCurrentChanged: Qt.callLater(root.ensureCurrentVisible)
    onItemsChanged: Qt.callLater(root.ensureCurrentVisible)
  }

                                                                              
                                                             
  Process {
    id: activeApSignalProc

    command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL", "device", "wifi", "list",
      "ifname", root.wifiDevice ? root.wifiDevice.name : "", "--rescan", "no"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.activeApSignal = Model.parseActiveApSignal(text)
    }
  }

  Timer {
    interval: 5000
    repeat: true
    triggeredOnStart: true
    running: root.needsActiveApSignal
    onTriggered: if (!activeApSignalProc.running) activeApSignalProc.running = true
  }

  onKindChanged: {
    if (root.kind !== "wifi") root.activeApSignal = -1
  }
}
