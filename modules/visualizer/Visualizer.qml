pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.config

Scope {
    id: root

    readonly property var levels: state.levels
    readonly property bool audioActive: state.audioActive

    function zeroLevels() {
        return Array(Constants.visualizerBarCount).fill(0)
    }

    function acceptFrame(frame) {
        const fields = frame.trim().split(";")
        if (fields[fields.length - 1] === "")
            fields.pop()
        if (fields.length !== Constants.visualizerBarCount)
            return

        const rawLevels = []
        for (const field of fields) {
            const value = Number(field)
            if (!isFinite(value) || value < 0 || value > Constants.visualizerInputRange)
                return
            rawLevels.push(value / Constants.visualizerInputRange)
        }

        let peak = 0
        for (const level of rawLevels)
            peak = Math.max(peak, level)
        if (peak <= Constants.visualizerActivityThreshold)
            return

        const visibleLevels = []
        for (let i = 0; i < rawLevels.length; i++) {
            const left = rawLevels[Math.max(0, i - 1)]
            const center = rawLevels[i]
            const right = rawLevels[Math.min(rawLevels.length - 1, i + 1)]
            const spatial = left * Constants.visualizerNeighborWeight
                + center * Constants.visualizerCenterWeight
                + right * Constants.visualizerNeighborWeight
            const amplified = Math.min(1, spatial * Constants.visualizerInputGain)
            visibleLevels.push(Math.pow(amplified, Constants.visualizerLevelCurve))
        }
        state.levels = visibleLevels
        state.audioActive = true
        silenceTimer.restart()
    }

    QtObject {
        id: state
        property var levels: root.zeroLevels()
        property bool audioActive: false
    }

    Process {
        id: cava
        running: true
        command: ["cava", "-p", Quickshell.shellPath("modules/visualizer/cava.conf")]

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => root.acceptFrame(data)
        }

        onRunningChanged: {
            if (!running) {
                silenceTimer.stop()
                state.audioActive = false
                state.levels = root.zeroLevels()
                restartTimer.restart()
            }
        }
    }

    Timer {
        id: silenceTimer
        interval: Constants.visualizerSilenceTimeout
        repeat: false
        onTriggered: {
            state.audioActive = false
            state.levels = root.zeroLevels()
        }
    }

    Timer {
        id: restartTimer
        interval: 3000
        repeat: false
        onTriggered: cava.running = true
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: panelWindow
            required property var modelData
            screen: modelData
            anchors.bottom: true
            anchors.left: true
            anchors.right: true
            margins.bottom: Constants.visualizerBottomMargin
            implicitHeight: Constants.visualizerHeight
            exclusionMode: ExclusionMode.Ignore
            aboveWindows: false
            color: "transparent"
            focusable: false
            visible: root.audioActive

            mask: Region {
                width: panelWindow.width
                height: panelWindow.height
                intersection: Intersection.Xor
            }

            Item {
                anchors.centerIn: parent
                width: Constants.visualizerBarCount * (Constants.visualizerBarWidth + Constants.visualizerBarSpacing)
                    - Constants.visualizerBarSpacing
                height: Constants.visualizerMaxBarHeight

                Repeater {
                    model: Constants.visualizerBarCount

                    Rectangle {
                        required property int index
                        readonly property real level: root.levels[index] ?? 0

                        x: index * (Constants.visualizerBarWidth + Constants.visualizerBarSpacing)
                        anchors.bottom: parent.bottom
                        width: Constants.visualizerBarWidth
                        height: root.audioActive
                            ? Math.max(
                                Constants.visualizerMinBarHeight,
                                level * Constants.visualizerMaxBarHeight
                            )
                            : 0
                        radius: Constants.visualizerBarRadius
                        gradient: Gradient {
                            orientation: Gradient.Vertical
                            GradientStop {
                                position: 0
                                color: Colors.visualizerTop
                            }
                            GradientStop {
                                position: 1
                                color: Colors.visualizerBottom
                            }
                        }

                        Behavior on height {
                            NumberAnimation {
                                duration: Constants.visualizerAnimationDuration
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }
            }
        }
    }
}

