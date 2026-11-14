pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../../config"
import "Model.js" as Model

PanelWindow {
    id: root

    property var targetScreen: null
    property bool open: false
    property string connectionName: ""

    property bool running: false
    property bool expectedStop: false
    property bool pendingRun: false
    property string phase: "" // "down" | "up" | ""
    property string stderrText: ""
    property string downloadMbps: ""
    property string uploadMbps: ""
    property string error: ""

    readonly property real downloadValue: Model.toMbps(downloadMbps)
    readonly property real uploadValue: Model.toMbps(uploadMbps)

    property var scaleStops: [100, 250, 500, 1000, 2500, 5000, 10000]
    property real fullScale: scaleStops[0]

    readonly property color onScrim: "white"
    readonly property color onScrimDim: Qt.rgba(1, 1, 1, 0.55)
    readonly property color onScrimUrgent: "#f7768e"
    readonly property color accentColor: "#7aa2f7"

    readonly property string speedTestScript: Quickshell.shellPath("modules/bar/components/network/scripts/qs-network-speedtest")

    signal closeRequested

    screen: targetScreen
    visible: open
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function openWith(connection) {
        root.connectionName = connection ? String(connection) : "Internet"
        resetScale()
        runSpeedTest()
    }

    function close() {
        phaseTimer.stop()
        root.phase = ""
        root.running = false
        if (speedTestProc.running) {
            root.expectedStop = true
            speedTestProc.running = false
        }
        root.closeRequested()
    }

    function resetScale() {
        fullScale = scaleStops[0]
    }

    function expandScale(value) {
        fullScale = Model.speedTestScale(value, scaleStops, fullScale)
    }

    onDownloadValueChanged: expandScale(downloadValue)
    onUploadValueChanged: expandScale(uploadValue)

    Behavior on fullScale {
        NumberAnimation { duration: 400; easing.type: Easing.OutCubic }
    }

    function updateSpeedTestLine(line) {
        var value = parseFloat(line)
        if (!isFinite(value) || value < 0) return
        if (phase === "down") downloadMbps = String(value)
        else if (phase === "up") uploadMbps = String(value)
    }

    function runSpeedTest() {
        if (speedTestProc.running) {
            if (expectedStop) pendingRun = true
            return
        }
        error = ""
        downloadMbps = ""
        uploadMbps = ""
        running = true
        resetScale()
        startPhase("down")
    }

    function startPhase(nextPhase) {
        expectedStop = false
        phase = nextPhase
        stderrText = ""
        speedTestProc.command = [root.speedTestScript, nextPhase]
        speedTestProc.running = true
        phaseTimer.restart()
    }

    function stopPhase() {
        phaseTimer.stop()
        if (speedTestProc.running) {
            expectedStop = true
            speedTestProc.running = false
            return
        }
        finishPhase()
    }

    function finishPhase() {
        if (phase === "down") {
            startPhase("up")
            return
        }
        phase = ""
        running = false
        expectedStop = false
    }

    onOpenChanged: {
        if (open) {
            Qt.callLater(() => {
                if (!root.open) return
                keyCatcher.forceActiveFocus()
                leftDial.ignite()
                rightDial.ignite()
            })
        } else {
            close()
        }
    }

    Process {
        id: speedTestProc
        stdout: SplitParser {
            onRead: function(line) { root.updateSpeedTestLine(line) }
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: {
                root.stderrText = String(text || "").trim()
                if (root.error !== "" && root.stderrText !== "") root.error = root.stderrText
            }
        }
        onExited: function(exitCode) {
            phaseTimer.stop()
            if (root.pendingRun) {
                root.pendingRun = false
                root.expectedStop = false
                if (root.open) Qt.callLater(root.runSpeedTest)
                return
            }
            if (!root.expectedStop && exitCode !== 0) {
                root.error = root.stderrText || "Speed test failed"
                root.phase = ""
                root.running = false
                return
            }
            root.expectedStop = false
            root.finishPhase()
        }
    }

    Timer {
        id: phaseTimer
        interval: 5000
        repeat: false
        onTriggered: root.stopPhase()
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.78)

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: root.open

        Keys.onEscapePressed: root.close()
        Keys.onReturnPressed: if (!root.running) root.runSpeedTest()
        Keys.onEnterPressed: if (!root.running) root.runSpeedTest()

        Item {
            id: cluster
            anchors.centerIn: parent
            width: content.implicitWidth
            height: content.implicitHeight

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: content
                anchors.centerIn: parent
                spacing: 20

                Text {
                    visible: root.connectionName !== ""
                    text: root.connectionName.toUpperCase()
                    color: root.onScrimDim
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Row {
                    spacing: 48
                    Layout.alignment: Qt.AlignHCenter

                    SpeedDial {
                        id: leftDial
                        label: "DOWNLOAD"
                        value: root.downloadValue
                        live: root.running && root.phase === "down"
                    }

                    SpeedDial {
                        id: rightDial
                        label: "UPLOAD"
                        value: root.uploadValue
                        live: root.running && root.phase === "up"
                    }
                }

                Rectangle {
                    id: runAgainBtn
                    visible: true
                    width: btnRow.implicitWidth + 28
                    height: 32
                    radius: Constants.radius
                    Layout.alignment: Qt.AlignHCenter
                    enabled: !root.running
                    opacity: root.running ? 0 : 1
                    color: runAgainMouse.containsMouse ? "#292e42" : "transparent"
                    border.color: runAgainMouse.containsMouse ? root.accentColor : Qt.rgba(1, 1, 1, 0.2)
                    border.width: 1

                    Behavior on opacity {
                        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                    }

                    Row {
                        id: btnRow
                        anchors.centerIn: parent
                        spacing: 8
                        Text {
                            text: "󰓅"
                            color: root.onScrim
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 13
                        }
                        Text {
                            text: "Run again"
                            color: root.onScrim
                            font.family: "JetBrainsMono Nerd Font"
                            font.pixelSize: 12
                            font.bold: true
                        }
                    }

                    MouseArea {
                        id: runAgainMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: root.running ? Qt.ArrowCursor : Qt.PointingHandCursor
                        onClicked: if (!root.running) root.runSpeedTest()
                    }
                }

                Text {
                    visible: root.error !== ""
                    text: root.error
                    color: root.onScrimUrgent
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    Layout.maximumWidth: 440
                    horizontalAlignment: Text.AlignHCenter
                }
            }
        }
    }

    component SpeedDial: Item {
        id: dial

        required property string label
        required property real value
        required property bool live

        readonly property real diameter: 210
        readonly property real dialStart: 135
        readonly property real dialSweep: 270
        readonly property int tickCount: 46
        readonly property real arcWidth: 4
        readonly property real arcRadius: diameter / 2 - arcWidth
        readonly property color trackColor: Qt.rgba(1, 1, 1, 0.14)
        readonly property color minorTickColor: Qt.rgba(1, 1, 1, 0.12)
        readonly property color majorTickColor: Qt.rgba(1, 1, 1, 0.3)
        readonly property bool engaged: live || value > 0

        property real shown: 0
        readonly property real reading: ignition.running ? value : shown
        readonly property real fullScale: root.fullScale
        readonly property real fraction: fullScale > 0 ? Math.max(0, Math.min(1, shown / fullScale)) : 0
        readonly property bool arcVisible: fraction > 0.004

        width: diameter
        height: diameter
        opacity: engaged ? 1 : 0.5

        Behavior on opacity {
            NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
        }

        Behavior on shown {
            enabled: !ignition.running
            NumberAnimation { duration: 600; easing.type: Easing.OutCubic }
        }

        onValueChanged: {
            if (!ignition.running) shown = value
        }

        function ignite() {
            ignition.restart()
        }

        SequentialAnimation {
            id: ignition
            NumberAnimation { target: dial; property: "shown"; to: dial.fullScale; duration: 550; easing.type: Easing.InOutCubic }
            NumberAnimation { target: dial; property: "shown"; to: 0; duration: 650; easing.type: Easing.OutCubic }
            onFinished: dial.shown = dial.value
        }

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeWidth: dial.arcWidth
                strokeColor: dial.trackColor
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: dial.width / 2
                    centerY: dial.height / 2
                    radiusX: dial.arcRadius
                    radiusY: dial.arcRadius
                    startAngle: dial.dialStart
                    sweepAngle: dial.dialSweep
                }
            }

            ShapePath {
                strokeWidth: dial.arcWidth * 3
                strokeColor: dial.arcVisible ? Qt.rgba(122/255, 162/255, 247/255, 0.18) : "transparent"
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: dial.width / 2
                    centerY: dial.height / 2
                    radiusX: dial.arcRadius
                    radiusY: dial.arcRadius
                    startAngle: dial.dialStart
                    sweepAngle: dial.dialSweep * dial.fraction
                }
            }

            ShapePath {
                strokeWidth: dial.arcWidth
                strokeColor: dial.arcVisible ? root.accentColor : "transparent"
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: dial.width / 2
                    centerY: dial.height / 2
                    radiusX: dial.arcRadius
                    radiusY: dial.arcRadius
                    startAngle: dial.dialStart
                    sweepAngle: dial.dialSweep * dial.fraction
                }
            }
        }

        Repeater {
            model: dial.tickCount

            Item {
                id: tickItem
                required property int index
                readonly property bool major: index % 5 === 0

                anchors.fill: parent
                rotation: dial.dialStart + (index / (dial.tickCount - 1)) * dial.dialSweep - 270

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: dial.arcWidth * 2 + (tickItem.major ? 0 : 2)
                    width: tickItem.major ? 2 : 1
                    height: tickItem.major ? 10 : 6
                    radius: width / 2
                    color: tickItem.major ? dial.majorTickColor : dial.minorTickColor
                }
            }
        }

        Item {
            anchors.fill: parent
            rotation: dial.dialStart + dial.fraction * dial.dialSweep - 270

            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: dial.arcWidth * 2 + 10
                width: 3
                height: dial.diameter * 0.32
                radius: width / 2

                gradient: Gradient {
                    GradientStop { position: 0.0; color: root.accentColor }
                    GradientStop { position: 0.55; color: root.accentColor }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            anchors.topMargin: 14
            spacing: 0

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: dial.reading.toFixed(dial.reading < 10 && dial.reading > 0 ? 1 : 0)
                color: root.onScrim
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 28
                font.bold: true
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Mbps"
                color: root.onScrimDim
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 11
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            text: dial.label
            color: root.onScrimDim
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 11
            font.bold: true
            font.letterSpacing: 1.5
        }
    }
}
