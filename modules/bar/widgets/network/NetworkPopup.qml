pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import "../../../../config"
import "../layout"
import "Model.js" as Model

Item {
    id: root

    property bool open: false
    property string barPosition: "top"

    width: 420
    implicitHeight: card.implicitHeight
    height: implicitHeight

    // Live connection details
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
    readonly property bool hasInternetPing: Model.internetPingReadable(internetPingSamples, connectivity)
    readonly property bool hasTransferStats: info.rx_bytes !== undefined

    readonly property bool networkManagerAvailable: NetworkRuntime.networkManagerAvailable
    readonly property var wiredDevice: NetworkRuntime.wiredDevice
    readonly property var wifiDevice: NetworkRuntime.wifiDevice
    readonly property var wifiNetworkObjects: wifiDevice && wifiDevice.networks ? wifiDevice.networks.values : []
    readonly property var connectedWifiNetwork: NetworkRuntime.connectedWifiNetwork
    readonly property bool canShareWifi: (root.kind === "wifi" || root.info.type === "wifi") && Model.canShareNetwork(connectedWifiNetwork, WifiSecurityType.Wpa2Eap, WifiSecurityType.WpaEap)
    readonly property bool canRunSpeedTest: !!(root.info.iface || (wiredDevice && wiredDevice.connected) || (wifiDevice && wifiDevice.connected))

    signal openWifiQrRequested(var payload)
    signal openSpeedTestRequested(string connectionName)

    property int connectionPhraseIndex: 0
    readonly property var connectionPhrases: [
        "Wiring bits",
        "Handling packets",
        "Sorting frames",
        "Hauling bytes",
        "Routing crumbs",
        "Counting collisions",
        "Bending light"
    ]
    readonly property string connectionPhrase: connectionPhrases[connectionPhraseIndex % connectionPhrases.length]

    property var wifiNetworks: []
    property bool wifiStationAvailable: false

    readonly property string dnsProvider: NetworkRuntime.dnsProvider
    readonly property string dnsPendingProvider: NetworkRuntime.dnsPendingProvider
    readonly property string dnsError: NetworkRuntime.dnsError
    readonly property string dnsConnectionUuid: NetworkRuntime.dnsConnectionUuid
    readonly property bool dnsBusy: NetworkRuntime.dnsBusy
    readonly property var dnsProviders: NetworkRuntime.dnsProviders
    property string customDnsText: ""
    property bool customDnsOpen: false

    property string actionSsid: ""
    property string actionKind: ""
    property string failureSsid: ""
    property string failureReason: ""
    property string passwordSsid: ""
    property string passwordText: ""

    readonly property bool busy: actionKind !== ""

    readonly property string kind: NetworkRuntime.kind

    readonly property int signalStrength: NetworkRuntime.signalStrength

    readonly property string connectivity: NetworkRuntime.connectivity

    readonly property bool hasCaptivePortal: connectivity === "portal"
    readonly property bool restricted: hasCaptivePortal || connectivity === "limited"
    readonly property string icon: Model.connectionIcon(kind, signalStrength, connectivity)

    function syncWifiNetworks() {
        var nets = []
        var networks = wifiNetworkObjects || []
        for (var i = 0; i < networks.length; i++) {
            var net = networks[i]
            if (!net) continue
            checkActionCompletion(net)
            var row = Model.wifiRow(net)
            if (row) nets.push(row)
        }
        wifiNetworks = Model.sortWifiRows(nets)
        wifiStationAvailable = !!wifiDevice
    }

    onOpenChanged: {
        if (open) {
            refresh()
            NetworkRuntime.registerDnsPopup(root)
        } else {
            cancelPasswordPrompt()
            NetworkRuntime.unregisterDnsPopup(root)
            connectionPhraseSwap.stop()
            header.subtitleOpacity = 1.0
            prevSampleTime = 0
            downloadRate = 0
            uploadRate = 0
            pingIface = ""
            routerPingSamples = []
            internetPingSamples = []
            routerPingLatency = -1
            internetPingLatency = -1
            internetPingPacketLoss = 0
        }
    }

    onWifiDeviceChanged: syncWifiNetworks()

    onWifiNetworkObjectsChanged: syncWifiNetworks()

    function refresh() {
        if (!detailsProc.running) detailsProc.running = true
        syncWifiNetworks()
    }

    function updateDetails(raw) {
        var next = Model.parseKeyValue(raw)
        info = next
        updateThroughput(next)
        updatePingLatency(next)
    }

    function setDns(provider, customServers) {
        if (dnsBusy || !dnsConnectionUuid) return
        customDnsOpen = false
        NetworkRuntime.setDns(provider, customServers)
    }

    function refreshActiveDnsProfile() { NetworkRuntime.refreshActiveDnsProfile() }

    function updateThroughput(next) {
        var state = Model.throughputState({
            prevIface: prevIface,
            prevRxBytes: prevRxBytes,
            prevTxBytes: prevTxBytes,
            prevSampleTime: prevSampleTime,
            downloadRate: downloadRate,
            uploadRate: uploadRate
        }, next, Date.now() / 1000)

        prevIface = state.prevIface
        prevRxBytes = state.prevRxBytes
        prevTxBytes = state.prevTxBytes
        prevSampleTime = state.prevSampleTime
        downloadRate = state.downloadRate
        uploadRate = state.uploadRate
    }

    function updatePingLatency(next) {
        var state = Model.pingLatencyState({
            pingIface: pingIface,
            routerPingSamples: routerPingSamples,
            internetPingSamples: internetPingSamples
        }, next, pingHistoryWindow, pingAverageWindow)

        pingIface = state.pingIface
        routerPingSamples = state.routerPingSamples
        internetPingSamples = state.internetPingSamples
        routerPingLatency = state.routerPingLatency
        internetPingLatency = state.internetPingLatency
        internetPingPacketLoss = state.internetPingPacketLoss
    }

    function copyToClipboard(value) {
        if (!value) return
        Quickshell.execDetached(["bash", "-c", "printf %s " + JSON.stringify(value) + " | wl-copy"])
    }

    function networkForSsid(ssid) {
        var networks = wifiNetworkObjects || []
        for (var i = 0; i < networks.length; i++) {
            if (networks[i] && networks[i].name === ssid) return networks[i]
        }
        return null
    }

    function runNetworkAction(kind, network, callback) {
        if (actionKind !== "" || !network) return
        var ssid = network.name || ""
        actionSsid = ssid
        actionKind = kind
        failureSsid = ""
        failureReason = ""
        callback(network)
        actionTimeout.restart()
    }

    function clearNetworkAction() {
        actionTimeout.stop()
        if (actionKind === "connect") cancelPasswordPrompt()
        failureSsid = ""
        failureReason = ""
        actionSsid = ""
        actionKind = ""
        refresh()
    }

    function failNetworkAction(network, reason) {
        if (!network || actionKind === "" || actionSsid !== (network.name || "")) return
        actionTimeout.stop()
        failureSsid = actionSsid
        failureReason = Model.networkFailureReason(reason, Model.requiresCredentials(network.security, WifiSecurityType.Open, WifiSecurityType.Owe), {
            NoSecrets: ConnectionFailReason.NoSecrets,
            WifiAuthTimeout: ConnectionFailReason.WifiAuthTimeout,
            WifiNetworkLost: ConnectionFailReason.WifiNetworkLost,
            WifiClientDisconnected: ConnectionFailReason.WifiClientDisconnected,
            WifiClientFailed: ConnectionFailReason.WifiClientFailed
        })
        actionSsid = ""
        actionKind = ""
        refresh()
    }

    function checkActionCompletion(network) {
        if (!network || actionKind === "" || actionSsid !== (network.name || "")) return
        if (Model.networkActionComplete(actionKind, network)) clearNetworkAction()
    }

    function connectDirectly(ssid) {
        runNetworkAction("connect", networkForSsid(ssid), function(net) { net.connect() })
    }

    function connectWithPassphrase(ssid, passphrase) {
        runNetworkAction("connect", networkForSsid(ssid), function(net) { net.connectWithPsk(passphrase) })
    }

    function disconnect(network) {
        runNetworkAction("disconnect", network || connectedWifiNetwork, function(net) { net.disconnect() })
    }

    function disconnectRow(ssid) {
        var net = networkForSsid(ssid)
        if (net) disconnect(net)
    }

    function forget(net) {
        runNetworkAction("forget", net ? networkForSsid(net.ssid) : null, function(network) { network.forget() })
    }

    function openPasswordPrompt(ssid) {
        if (passwordSsid !== ssid) {
            passwordText = ""
        }
        passwordSsid = ssid
    }

    function cancelPasswordPrompt() {
        passwordSsid = ""
        passwordText = ""
    }

    Component.onCompleted: {
        refresh()
        if (open) NetworkRuntime.registerDnsPopup(root)
    }

    Component.onDestruction: NetworkRuntime.unregisterDnsPopup(root)

    function toggleWifi() {
        if (!networkManagerAvailable) return
        Networking.wifiEnabled = !Networking.wifiEnabled
        Qt.callLater(() => root.refresh())
    }

    function openWifiQr() {
        var payload = {}
        if (root.info.iface) payload.iface = root.info.iface
        else if (wifiDevice) payload.iface = wifiDevice.name || ""
        if (connectedWifiNetwork) payload.ssid = connectedWifiNetwork.name || ""
        else if (root.info.ssid) payload.ssid = root.info.ssid
        root.openWifiQrRequested(payload)
    }

    function openSpeedTest() {
        var name = ""
        if (root.kind === "wifi" && connectedWifiNetwork) name = connectedWifiNetwork.name || "Wi-Fi"
        else if (root.info.type === "wifi") name = root.info.ssid || "Wi-Fi"
        else if (root.kind === "ethernet" || root.info.type === "ethernet") name = "Ethernet"
        else name = root.info.iface || "Internet"
        root.openSpeedTestRequested(name)
    }

    Timer {
        id: connectionPhraseTimer
        interval: 2800
        running: root.open && !root.restricted && (root.kind === "wifi" || root.kind === "ethernet") && (root.connectedWifiNetwork || root.kind === "ethernet")
        repeat: true
        onTriggered: connectionPhraseSwap.restart()
    }

    SequentialAnimation {
        id: connectionPhraseSwap
        PropertyAnimation {
            target: header
            property: "subtitleOpacity"
            to: 0.0
            duration: 180
            easing.type: Easing.OutQuad
        }
        ScriptAction {
            script: root.connectionPhraseIndex = (root.connectionPhraseIndex + 1) % root.connectionPhrases.length
        }
        PropertyAnimation {
            target: header
            property: "subtitleOpacity"
            to: 1.0
            duration: 260
            easing.type: Easing.InQuad
        }
    }

    // Process to poll IP, Gateway, rx/tx bytes, and pings
    Process {
        id: detailsProc
        command: ["bash", "-c",
            'gw=$(ip route get 1.1.1.1 2>/dev/null | awk \'{for(i=1;i<=NF;i++)if($i=="via"){print $(i+1);exit}}\');' +
            'dev=$(ip route get 1.1.1.1 2>/dev/null | awk \'{for(i=1;i<=NF;i++)if($i=="dev"){print $(i+1);exit}}\');' +
            'src=$(ip route get 1.1.1.1 2>/dev/null | awk \'{for(i=1;i<=NF;i++)if($i=="src"){print $(i+1);exit}}\');' +
            'rx=$(cat /sys/class/net/$dev/statistics/rx_bytes 2>/dev/null || echo 0);' +
            'tx=$(cat /sys/class/net/$dev/statistics/tx_bytes 2>/dev/null || echo 0);' +
            'rping=$(ping -n -c 1 -W 1 "$gw" 2>/dev/null | awk -F\'time[=<]\' \'/time[=<]/{split($2,p," ");print p[1];exit}\');' +
            'iping=$(ping -n -c 1 -W 1 1.1.1.1 2>/dev/null | awk -F\'time[=<]\' \'/time[=<]/{split($2,p," ");print p[1];exit}\');' +
            'printf "iface\\t%s\\nip\\t%s\\ngateway\\t%s\\nrx_bytes\\t%s\\ntx_bytes\\t%s\\nrouter_ping_ms\\t%s\\ninternet_ping_ms\\t%s\\n" "$dev" "$src" "$gw" "$rx" "$tx" "$rping" "$iping"'
        ]
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: root.updateDetails(text)
        }
    }

    Timer {
        id: detailsPoll
        interval: 1500
        repeat: true
        running: root.open
        onTriggered: if (!detailsProc.running) detailsProc.running = true
    }

    Timer {
        id: actionTimeout
        interval: 30000
        repeat: false
        onTriggered: {
            if (!root.actionKind) return
            root.failureSsid = root.actionSsid
            root.failureReason = "Timed out"
            root.actionSsid = ""
            root.actionKind = ""
            root.refresh()
        }
    }

    // Observe outside the virtualized list so off-screen actions still finish.
    Repeater {
        model: root.wifiNetworkObjects

        delegate: Item {
            id: wifiNetworkObserver
            required property var modelData
            width: 0
            height: 0

            Connections {
                target: wifiNetworkObserver.modelData

                function onConnectedChanged() {
                    root.syncWifiNetworks()
                    root.refreshActiveDnsProfile()
                }

                function onKnownChanged() {
                    root.syncWifiNetworks()
                }

                function onStateChangingChanged() {
                    root.syncWifiNetworks()
                }

                function onSignalStrengthChanged() {
                    root.syncWifiNetworks()
                }

                function onConnectionFailed(reason) {
                    var network = wifiNetworkObserver.modelData
                    var ssid = network ? network.name || "" : ""
                    var ours = network && root.actionKind === "connect" && root.actionSsid === ssid
                    var needsCredentials = network && Model.requiresCredentials(network.security, WifiSecurityType.Open, WifiSecurityType.Owe)
                    root.failNetworkAction(network, reason)
                    if (ours && Model.shouldRepromptPassphrase(reason, needsCredentials, {
                        NoSecrets: ConnectionFailReason.NoSecrets,
                        WifiAuthTimeout: ConnectionFailReason.WifiAuthTimeout
                    })) root.openPasswordPrompt(ssid)
                    root.syncWifiNetworks()
                }
            }
        }
    }

    PopupSurface {
        id: card
        open: root.open
        barPosition: root.barPosition
        anchors.fill: parent
        implicitHeight: contentColumn.implicitHeight + 28
        clip: true

        Column {
            id: contentColumn
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 12

            // ---------- Hero: Network Icon · SSID / Connection · Switch ----------
            PopupHeader {
                id: header
                width: parent.width
                iconText: root.icon
                iconColor: root.restricted ? Colors.statusDanger : Colors.foregroundStrong
                subtitleColor: root.restricted ? Colors.statusDanger : Colors.foregroundQuiet
                title: {
                            if (root.kind === "wifi" && root.connectedWifiNetwork) return root.connectedWifiNetwork.name || "Wi-Fi"
                            if (root.info.type === "wifi") return root.info.ssid || "Wi-Fi"
                            if (root.info.type === "ethernet" || root.kind === "ethernet") return "Ethernet"
                            return root.info.iface || (root.kind === "disconnected" ? "Disconnected" : "No Connection")
                        }
                subtitle: {
                            if (root.hasCaptivePortal) return "SIGN-IN REQUIRED"
                            if (root.restricted) return "LIMITED ACCESS"
                            if (root.kind === "wifi" && root.connectedWifiNetwork) return root.connectionPhrase.toUpperCase()
                            if (root.kind === "ethernet") return root.connectionPhrase.toUpperCase()
                            return "NOT CONNECTED"
                        }

                    Rectangle {
                        id: qrBtn
                        visible: root.canShareWifi
                        width: 24
                        height: 24
                        radius: Constants.radius
                        color: qrMouse.containsMouse ? "#292e42" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰐲"
                            color: qrMouse.containsMouse ? "#c0caf5" : "#78809a"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 21
                        }

                        MouseArea {
                            id: qrMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openWifiQr()
                        }
                    }

                    Rectangle {
                        id: speedBtn
                        visible: root.canRunSpeedTest
                        width: 24
                        height: 24
                        radius: Constants.radius
                        color: speedMouse.containsMouse ? "#292e42" : "transparent"

                        Text {
                            anchors.centerIn: parent
                            text: "󰓅"
                            color: speedMouse.containsMouse ? "#c0caf5" : "#78809a"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 21
                        }

                        MouseArea {
                            id: speedMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.openSpeedTest()
                        }
                    }

                    ToggleSwitch {
                        id: powerSwitch
                        checked: Networking.wifiEnabled
                        onToggled: root.toggleWifi()
                    }
            }

            // ---------- Captive Portal Banner ----------
            Rectangle {
                visible: root.hasCaptivePortal
                width: parent.width
                height: 32
                radius: Constants.radius
                color: "#292e42"
                border.color: "#f7768e"
                border.width: 1

                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text {
                        text: "󰏌"
                        color: "#f7768e"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 13
                    }
                    Text {
                        text: "Sign in to network"
                        color: "#c0caf5"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 12
                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Quickshell.execDetached(["xdg-open", Model.captivePortalUrl])
                }
            }

            // ---------- Connection Details Grid ----------
            Column {
                id: detailsSection
                visible: root.kind !== "disconnected" && !!root.info.iface
                width: parent.width
                spacing: 8

                GridLayout {
                    width: parent.width
                    columns: 4
                    columnSpacing: 16
                    rowSpacing: 4

                    // Row 1: Ping & Packet Loss
                    Text {
                        text: "Ping"
                        color: "#a9b1d6"
                        opacity: 0.6
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: Model.formatPingLatency(root.internetPingLatency, root.hasInternetPing)
                        color: root.hasInternetPing && root.internetPingPacketLoss > 0 ? "#f7768e" : "#c0caf5"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Packet Loss"
                        color: "#a9b1d6"
                        opacity: 0.6
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: Model.formatPacketLoss(root.internetPingPacketLoss, root.hasInternetPing)
                        color: root.hasInternetPing && root.internetPingPacketLoss > 0 ? "#f7768e" : "#c0caf5"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }

                    // Row 2: Receiving & Sending
                    Text {
                        text: "Receiving"
                        color: "#a9b1d6"
                        opacity: 0.6
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: root.hasTransferStats ? Model.formatRate(root.downloadRate) : "--"
                        color: "#c0caf5"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Sending"
                        color: "#a9b1d6"
                        opacity: 0.6
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: root.hasTransferStats ? Model.formatRate(root.uploadRate) : "--"
                        color: "#c0caf5"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }

                    // Row 3: Downloaded & Uploaded
                    Text {
                        text: "Downloaded"
                        color: "#a9b1d6"
                        opacity: 0.6
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: root.hasTransferStats ? Model.formatBytes(parseFloat(root.info.rx_bytes || "0")) : "--"
                        color: "#c0caf5"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }

                    Text {
                        text: "Uploaded"
                        color: "#a9b1d6"
                        opacity: 0.6
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: root.hasTransferStats ? Model.formatBytes(parseFloat(root.info.tx_bytes || "0")) : "--"
                        color: "#c0caf5"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }

                    // Row 4: IP Address & Gateway
                    Text {
                        text: "IP Address"
                        color: "#a9b1d6"
                        opacity: 0.6
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: root.info.ip || "--"
                        color: "#c0caf5"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.copyToClipboard(root.info.ip)
                        }
                    }

                    Text {
                        text: "Gateway"
                        color: "#a9b1d6"
                        opacity: 0.6
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                    }
                    Text {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: root.info.gateway || "--"
                        color: "#c0caf5"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.copyToClipboard(root.info.gateway)
                        }
                    }
                }
            }

            // ---------- DNS Provider Pills ----------
            Item {
                width: parent.width
                height: 6

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 0.75
                    color: "#414868"
                }
            }

            Column {
                id: dnsSection
                width: parent.width
                spacing: 6

                Text {
                    text: "DNS PROVIDER"
                    color: "#565f89"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 10
                    font.bold: true
                    font.letterSpacing: 1.2
                }

                Row {
                    width: parent.width
                    spacing: 6

                    readonly property real pillWidth: (width - spacing * 3) / 4

                    Repeater {
                        model: root.dnsProviders

                        delegate: Rectangle {
                            required property var modelData
                            readonly property bool isCurrent: root.dnsProvider === modelData
                            width: parent.pillWidth
                            height: 32
                            radius: Constants.radius
                            color: isCurrent ? "#323647" : (pillMouse.containsMouse ? "#262734" : "transparent")
                            border.color: pillMouse.containsMouse ? "#565f89" : "#414868"
                            border.width: 1

                            Text {
                                anchors.centerIn: parent
                                text: modelData
                                color: isCurrent ? "#c0caf5" : "#a9b1d6"
                                font.family: "JetBrainsMono Nerd Font"
                                font.pixelSize: 11
                                font.bold: isCurrent
                            }

                            MouseArea {
                                id: pillMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: !root.dnsBusy && root.dnsConnectionUuid !== ""
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    NetworkRuntime.clearDnsError()
                                    if (modelData === "Custom") {
                                        root.customDnsText = ""
                                        root.customDnsOpen = true
                                    } else {
                                        root.setDns(modelData)
                                    }
                                }
                            }
                        }
                    }
                }

                Row {
                    visible: root.customDnsOpen
                    width: parent.width
                    spacing: 6

                    TextField {
                        id: customDnsInput
                        width: parent.width - 86
                        height: 32
                        text: root.customDnsText
                        placeholderText: "DNS server IPs, separated by spaces"
                        color: "#c0caf5"
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        leftPadding: 8
                        background: Rectangle {
                            color: "#1a1b26"
                            border.color: "#414868"
                            border.width: 1
                            radius: Constants.radius
                        }
                        onTextChanged: root.customDnsText = text
                        onAccepted: root.setDns("Custom", text)
                    }

                    Rectangle {
                        width: 42
                        height: 32
                        radius: Constants.radius
                        color: root.dnsBusy ? "#414868" : "#323647"
                        Text {
                            anchors.centerIn: parent
                            text: root.dnsBusy ? "…" : "Set"
                            color: "#c0caf5"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 11
                        }
                        MouseArea {
                            anchors.fill: parent
                            enabled: !root.dnsBusy
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.setDns("Custom", customDnsInput.text)
                        }
                    }

                    Rectangle {
                        width: 32
                        height: 32
                        radius: Constants.radius
                        color: "#262734"
                        border.color: "#414868"
                        border.width: 1
                        Text {
                            anchors.centerIn: parent
                            text: "×"
                            color: "#a9b1d6"
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.customDnsOpen = false
                        }
                    }
                }

                Text {
                    visible: root.dnsError !== ""
                    width: parent.width
                    text: root.dnsError
                    color: "#f7768e"
                    wrapMode: Text.Wrap
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                }
            }

            // ---------- Wi-Fi Networks List ----------
            Item {
                visible: wifiSection.visible
                width: parent.width
                height: 6

                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width
                    height: 0.75
                    color: "#414868"
                }
            }

            Column {
                id: wifiSection
                visible: root.wifiStationAvailable
                width: parent.width
                spacing: 6

                ListView {
                    id: networkList
                    width: parent.width
                    height: Math.min(contentHeight, 240)
                    spacing: 4
                    clip: true
                    interactive: contentHeight > height
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.wifiNetworks

                    delegate: Column {
                        id: delegateCol
                        required property var modelData
                        required property int index

                        readonly property string sectionTitle: Model.wifiSectionTitle(root.wifiNetworks, index)
                        readonly property bool isConnected: modelData.connected
                        readonly property bool isPasswordOpen: root.passwordSsid !== "" && root.passwordSsid === modelData.ssid
                        readonly property bool isBusy: root.actionKind !== "" && root.actionSsid === modelData.ssid
                        readonly property bool isFailed: root.failureReason !== "" && root.failureSsid === modelData.ssid
                        readonly property bool canForget: Model.canForgetNetwork(modelData)
                        readonly property bool requiresCredentials: Model.requiresCredentials(modelData.security, WifiSecurityType.Open, WifiSecurityType.Owe)

                        width: networkList.width
                        spacing: 4

                        SectionHeader {
                            visible: delegateCol.sectionTitle !== ""
                            text: delegateCol.sectionTitle
                            color: "#78809a"
                            topPadding: 2
                        }

                        DeviceEntry {
                            id: rowRect
                            width: parent.width
                            iconText: Model.wifiIconFor(delegateCol.modelData.signal)
                            label: delegateCol.modelData.ssid || "Hidden Network"
                            subtitle: {
                                if (delegateCol.isPasswordOpen) return ""
                                if (delegateCol.isBusy && root.actionKind === "connect") return "Connecting..."
                                if (delegateCol.isBusy && root.actionKind === "disconnect") return "Disconnecting..."
                                if (delegateCol.isBusy && root.actionKind === "forget") return "Forgetting..."
                                if (delegateCol.isFailed) return root.failureReason || "Failed"
                                if (delegateCol.isConnected && root.hasCaptivePortal) return "Sign-in required"
                                if (delegateCol.isConnected) return "Connected"
                                return ""
                            }
                            subtitleColor: delegateCol.isFailed ? "#f7768e" : "#a9b1d6"
                            active: delegateCol.isConnected
                            expanded: delegateCol.isPasswordOpen
                            actionVisible: delegateCol.requiresCredentials || delegateCol.canForget
                            actionText: delegateCol.canForget && hovered ? "󰅙" : "󰌾"
                            actionColor: delegateCol.canForget && hovered ? "#f7768e" : "#78809a"
                            actionEnabled: delegateCol.canForget && !root.busy
                            rowEnabled: !root.busy
                            onActivated: {
                                if (delegateCol.isConnected) {
                                    root.disconnectRow(delegateCol.modelData.ssid)
                                    return
                                }
                                if (delegateCol.requiresCredentials && !delegateCol.modelData.known) {
                                    root.openPasswordPrompt(delegateCol.modelData.ssid)
                                    return
                                }
                                root.connectDirectly(delegateCol.modelData.ssid)
                            }
                            onActionClicked: root.forget(delegateCol.modelData)

                            // Passphrase input box
                            Item {
                                id: passwordBox
                                visible: delegateCol.isPasswordOpen
                                width: parent.width
                                height: 30

                                Timer {
                                    interval: 2000
                                    running: delegateCol.isFailed && delegateCol.isPasswordOpen
                                    onTriggered: {
                                        root.failureSsid = ""
                                        root.failureReason = ""
                                        pwInput.forceActiveFocus()
                                    }
                                }

                                Rectangle {
                                    anchors.fill: parent
                                    visible: delegateCol.isBusy || delegateCol.isFailed
                                    radius: Constants.radius
                                    color: "#262734"
                                    border.color: "#414868"

                                    Text {
                                        anchors.centerIn: parent
                                        text: delegateCol.isFailed ? root.failureReason : "Connecting..."
                                        color: delegateCol.isFailed ? "#f7768e" : "#a9b1d6"
                                        font.family: "JetBrainsMono Nerd Font"
                                        font.pixelSize: 10
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    spacing: 6
                                    visible: !delegateCol.isBusy && !delegateCol.isFailed

                                    Rectangle {
                                        Layout.fillWidth: true
                                        height: 28
                                        radius: Constants.radius
                                        color: "#1a1b26"
                                        border.color: "#7aa2f7"
                                        border.width: 1

                                        TextInput {
                                            id: pwInput
                                            anchors.fill: parent
                                            anchors.margins: 6
                                            echoMode: TextInput.Password
                                            color: "#c0caf5"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            clip: true
                                            enabled: !root.busy
                                            text: delegateCol.isPasswordOpen ? root.passwordText : ""
                                            onTextChanged: if (delegateCol.isPasswordOpen && text !== root.passwordText) root.passwordText = text
                                            onAccepted: {
                                                if (!root.busy && text.length > 0)
                                                    root.connectWithPassphrase(delegateCol.modelData.ssid, text)
                                            }
                                            Keys.onEscapePressed: root.cancelPasswordPrompt()
                                            onVisibleChanged: if (visible && delegateCol.isPasswordOpen) Qt.callLater(forceActiveFocus)
                                            Component.onCompleted: if (visible && delegateCol.isPasswordOpen) Qt.callLater(forceActiveFocus)
                                        }
                                    }

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: Constants.radius
                                        color: "#7aa2f7"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰄬"
                                            color: "#1a1b26"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                            font.bold: true
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (!root.busy && pwInput.text.length > 0)
                                                    root.connectWithPassphrase(delegateCol.modelData.ssid, pwInput.text)
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: 28
                                        height: 28
                                        radius: Constants.radius
                                        color: "#262734"
                                        border.color: "#414868"
                                        border.width: 1
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰅖"
                                            color: "#a9b1d6"
                                            font.family: "JetBrainsMono Nerd Font"
                                            font.pixelSize: 12
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.cancelPasswordPrompt()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
