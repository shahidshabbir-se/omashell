pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import "../../../../config"
import "../layout"
import "Model.js" as Model

Item {
    id: root

    property bool open: false
    property string barPosition: Constants.barPosition

    width: 360
    implicitHeight: card.implicitHeight
    height: implicitHeight

    readonly property var adapter: BluetoothRuntime.adapter
    readonly property var rows: Model.deviceRows(BluetoothRuntime.devices, adapter && adapter.discovering, pendingPairAddress)
    property string pendingForgetAddress: ""
    property string pendingPairAddress: ""
    property string pairFailureReason: ""

    property int phraseIndex: 0
    readonly property var activePhrases: [
        "Untangling wires",
        "Streaming vikings",
        "Pairing mysteries",
        "Herding headsets",
        "Taming radios",
        "Summoning speakers",
        "Wrangling codecs",
        "Polishing packets"
    ]
    readonly property bool rotatingPhrases: !!root.adapter && root.adapter.enabled
        && !root.pendingPairAddress && !root.pendingForgetAddress
    readonly property string heroStatusText: !root.adapter ? "NO ADAPTER"
        : !root.adapter.enabled ? "TURNED OFF"
        : activePhrases[phraseIndex % activePhrases.length].toUpperCase()

    function deviceFor(address) {
        var devices = BluetoothRuntime.devices || []
        for (var i = 0; i < devices.length; i++)
            if (devices[i] && devices[i].address === address) return devices[i]
        return null
    }

    function activateDevice(row) {
        var device = deviceFor(row.address)
        if (!device || device.pairing || pendingPairAddress === device.address
            || pendingForgetAddress === device.address
            || device.state === BluetoothDeviceState.Connecting
            || device.state === BluetoothDeviceState.Disconnecting) return
        pairFailureReason = ""
        if (device.connected) device.disconnect()
        else if (device.paired || device.bonded) device.connect()
        else {
            if (pendingPairAddress) return
            pendingPairAddress = device.address
            device.pair()
        }
    }

    function finishPendingPair() {
        if (!pendingPairAddress || pairConnect.running) return
        var device = deviceFor(pendingPairAddress)
        if (device && device.pairing) return
        if (!device || !(device.paired || device.bonded)) {
            pendingPairAddress = ""
            pairFailureReason = "Pairing failed. Put the device in pairing mode and retry."
            return
        }
        // Native connect() skips an open pairing link; BlueZ Connect still connects its profiles.
        pairConnect.command = ["busctl", "--system", "--timeout=20s", "call", "org.bluez",
            device.dbusPath, "org.bluez.Device1", "Connect"]
        pairConnect.running = true
    }

    function finishPairConnect(exitCode, error) {
        pendingPairAddress = ""
        if (exitCode !== 0)
            pairFailureReason = "Paired, but could not connect. " + String(error || "").trim()
    }

    Process {
        id: pairConnect
        stderr: StdioCollector { id: pairConnectError; waitForEnd: true }
        onExited: function(exitCode) { root.finishPairConnect(exitCode, pairConnectError.text) }
    }

    Connections {
        id: pairConnection
        target: root.pendingPairAddress ? root.deviceFor(root.pendingPairAddress) : null
        function onPairingChanged() {
            if (pairConnection.target && !pairConnection.target.pairing)
                Qt.callLater(root.finishPendingPair)
        }
    }

    Connections {
        target: BluetoothRuntime
        function onDevicesChanged() {
            if (root.pendingPairAddress && !root.deviceFor(root.pendingPairAddress))
                root.finishPendingPair()
        }
    }

    function forgetDevice(row) {
        var device = deviceFor(row.address)
        if (!device || device.pairing || pendingPairAddress === device.address
            || pendingForgetAddress || !(device.paired || device.bonded || device.trusted)) return
        if (!device.connected) {
            device.forget()
            return
        }
        pendingForgetAddress = device.address
        forgetTimeout.restart()
        if (device.state !== BluetoothDeviceState.Disconnecting) device.disconnect()
    }

    function finishPendingForget() {
        if (!pendingForgetAddress) return
        var address = pendingForgetAddress
        var device = deviceFor(address)
        if (!device) {
            pendingForgetAddress = ""
            forgetTimeout.stop()
            return
        }
        if (device.connected) return
        pendingForgetAddress = ""
        forgetTimeout.stop()
        device.forget()
    }

    Connections {
        target: root.pendingForgetAddress ? root.deviceFor(root.pendingForgetAddress) : null
        function onConnectedChanged() { root.finishPendingForget() }
    }

    Timer {
        id: forgetTimeout
        interval: 10000
        repeat: false
        onTriggered: root.pendingForgetAddress = ""
    }

    Timer {
        id: phraseTimer
        interval: 2800
        running: root.open && root.rotatingPhrases
        repeat: true
        onTriggered: phraseSwap.restart()
    }

    SequentialAnimation {
        id: phraseSwap
        PropertyAnimation {
            target: header
            property: "subtitleOpacity"
            to: 0.0
            duration: 180
            easing.type: Easing.OutQuad
        }
        ScriptAction {
            script: root.phraseIndex = (root.phraseIndex + 1) % root.activePhrases.length
        }
        PropertyAnimation {
            target: header
            property: "subtitleOpacity"
            to: 1.0
            duration: 260
            easing.type: Easing.InQuad
        }
    }

    Connections {
        target: root
        function onRotatingPhrasesChanged() {
            if (!root.rotatingPhrases) {
                phraseSwap.stop()
                header.subtitleOpacity = 1.0
            }
        }
    }

    PopupSurface {
        id: card
        anchors.fill: parent
        open: root.open
        barPosition: root.barPosition
        implicitWidth: content.implicitWidth + Constants.paddingLg * 2
        implicitHeight: content.implicitHeight + Constants.paddingLg * 2

        Column {
            id: content
            x: Constants.paddingLg
            y: Constants.paddingLg
            width: root.width - Constants.paddingLg * 2
            spacing: Constants.spacingMd

            PopupHeader {
                id: header
                width: parent.width
                iconText: "󰂯"
                title: "Bluetooth"
                subtitle: root.heroStatusText

                ToggleSwitch {
                    visible: root.adapter !== null
                    checked: !!root.adapter && root.adapter.enabled
                    onToggled: if (root.adapter) root.adapter.enabled = !root.adapter.enabled
                }
            }

            Rectangle {
                width: parent.width
                height: 1
                color: Colors.foregroundQuiet
            }

            ListView {
                id: deviceList
                width: parent.width
                height: Math.min(contentHeight, 360)
                spacing: Constants.spacingXs
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                interactive: contentHeight > height
                model: root.rows

                delegate: Item {
                    required property var modelData
                    width: ListView.view.width
                    height: modelData.kind === "header" ? 22 : deviceEntry.implicitHeight

                    SectionHeader {
                        visible: modelData.kind === "header"
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        text: modelData.label
                        font.letterSpacing: 1
                    }

                    DeviceEntry {
                        id: deviceEntry
                        width: parent.width
                        visible: modelData.kind === "device"
                        iconText: "󰂯"
                        label: modelData.label
                        subtitle: root.pendingForgetAddress === modelData.address ? "Forgetting…"
                            : root.pendingPairAddress === modelData.address ? (pairConnect.running ? "Connecting…" : "Pairing…")
                            : modelData.pairing ? "Pairing…"
                            : modelData.state === BluetoothDeviceState.Connecting ? "Connecting…"
                            : modelData.state === BluetoothDeviceState.Disconnecting ? "Disconnecting…"
                            : modelData.batteryAvailable && modelData.connected ? Math.round(modelData.battery * 100) + "% battery"
                            : modelData.connected ? "Connected" : ""
                        active: modelData.kind === "device" && !!modelData.connected
                        actionVisible: modelData.kind === "device" && !!modelData.known
                        actionText: hovered ? "󰅙" : ""
                        actionColor: actionHovered ? "#f7768e" : "#a9b1d6"
                        actionEnabled: modelData.kind === "device" && !!modelData.known
                            && !modelData.pairing && root.pendingPairAddress !== modelData.address
                            && !root.pendingForgetAddress
                        rowEnabled: !modelData.pairing && root.pendingPairAddress !== modelData.address
                            && root.pendingForgetAddress !== modelData.address
                        onActivated: root.activateDevice(modelData)
                        onActionClicked: root.forgetDevice(modelData)
                    }
                }
            }

            Text {
                visible: root.pairFailureReason !== ""
                width: parent.width
                text: root.pairFailureReason
                color: Colors.statusDanger
                font.family: Constants.fontFamily
                font.pixelSize: Constants.fontSizeMd
                wrapMode: Text.WordWrap
            }

            Text {
                visible: root.rows.length === 0
                width: parent.width
                text: !root.adapter ? "No Bluetooth adapter is available."
                    : !root.adapter.enabled ? "Turn Bluetooth on to connect devices."
                    : root.adapter.discovering ? "Searching for nearby devices…"
                    : "No devices found."
                color: Colors.muted
                font.family: Constants.fontFamily
                font.pixelSize: Constants.fontSizeMd
                wrapMode: Text.WordWrap
            }
        }
    }
}
