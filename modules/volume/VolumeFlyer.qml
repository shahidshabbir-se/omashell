pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../../config"
import "../bar/components/layout"

PanelWindow {
    id: root

    property var output: null
    property bool open: false
    property real volume: 0
    property bool muted: false

    readonly property bool hovered: open && pointer.containsMouse
    signal toggleMute()
    signal nudge(real delta)

    readonly property real level: muted ? 0 : Math.max(0, Math.min(1, volume))
    readonly property real overflowT: muted
        ? 0
        : Math.max(0, Math.min(1, (volume - 1) / 0.5))
    readonly property int percent: muted ? 0 : Math.round(volume * 100)
    readonly property string percentLabel: muted ? "muted" : (percent + "%")
    readonly property int flyerWidth: Constants.volumeOsdWidth
    readonly property int flyerHeight: Constants.volumeOsdHeight
    readonly property int bottomGap: Constants.visualizerHeight + Constants.spacingXl
    readonly property color toneStart: mixColor(
        Colors.accentViolet,
        Colors.statusDanger,
        overflowT * 0.45
    )
    readonly property color toneEnd: mixColor(Colors.accent, Colors.statusDanger, overflowT)
    readonly property color fillColor: muted ? Colors.statusDanger : toneEnd

    function mixColor(a, b, t) {
        const u = Math.max(0, Math.min(1, t))
        return Qt.rgba(
            a.r * (1 - u) + b.r * u,
            a.g * (1 - u) + b.g * u,
            a.b * (1 - u) + b.b * u,
            a.a * (1 - u) + b.a * u
        )
    }

    property bool visibleSurface: false

    screen: output
    visible: (open || visibleSurface) && output !== null
    color: "transparent"
    implicitWidth: flyerWidth
    implicitHeight: flyerHeight
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: true
    focusable: false
    surfaceFormat.opaque: false

    anchors.bottom: true

    margins {
        bottom: bottomGap
    }

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-volume-osd"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    onOpenChanged: {
        if (open) {
            visibleSurface = true
            hideAnim.stop()
            showAnim.restart()
        } else if (visibleSurface) {
            showAnim.stop()
            hideAnim.restart()
        }
    }

    SequentialAnimation {
        id: showAnim
        ParallelAnimation {
            NumberAnimation {
                target: flyer
                property: "opacity"
                to: 1
                duration: Constants.popupEnterMs
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: flyer
                property: "scale"
                to: 1
                duration: Constants.popupEnterMs
                easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: flyer
                property: "slideOffset"
                to: 0
                duration: Constants.popupEnterMs
                easing.type: Easing.OutCubic
            }
        }
    }

    SequentialAnimation {
        id: hideAnim
        ParallelAnimation {
            NumberAnimation {
                target: flyer
                property: "opacity"
                to: 0
                duration: Constants.popupExitMs
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: flyer
                property: "scale"
                to: Constants.popupFromScale
                duration: Constants.popupExitMs
                easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: flyer
                property: "slideOffset"
                to: 8
                duration: Constants.popupExitMs
                easing.type: Easing.InCubic
            }
        }
        ScriptAction {
            script: root.visibleSurface = false
        }
    }

    PopupSurface {
        id: flyer

        anchors.fill: parent
        open: root.open
        animated: false
        opacity: 0
        scale: Constants.popupFromScale
        transformOrigin: Item.Bottom
        slideOffset: 8

        MouseArea {
            id: pointer
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onClicked: root.toggleMute()
            onWheel: event => {
                if (event.angleDelta.y === 0)
                    return
                root.nudge(event.angleDelta.y > 0 ? Constants.volumeStep : -Constants.volumeStep)
                event.accepted = true
            }
        }

        RowLayout {
            anchors {
                fill: parent
                leftMargin: Constants.paddingLg
                rightMargin: Constants.paddingLg
            }
            spacing: Constants.spacingSm

            Item {
                Layout.preferredWidth: Constants.iconSizeLg
                Layout.preferredHeight: Constants.iconSizeLg

                Text {
                    anchors.fill: parent
                    text: "󰕾"
                    font.family: Constants.fontFamily
                    font.pixelSize: Constants.iconSizeLg
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    color: root.fillColor
                    opacity: root.muted ? 0.55 : 1
                }

                Rectangle {
                    visible: root.muted
                    anchors.centerIn: parent
                    width: parent.width + 2
                    height: 1.5
                    rotation: -32
                    color: Colors.statusDanger
                    antialiasing: true
                }
            }

            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 10

                Rectangle {
                    id: track

                    anchors.fill: parent
                    color: Colors.withAlpha(Colors.foregroundStrong, 0.12)

                    Item {
                        width: parent.width * root.level
                        height: parent.height
                        clip: true

                        Behavior on width {
                            NumberAnimation {
                                duration: Constants.animationFast
                                easing.type: Easing.OutCubic
                            }
                        }

                        Rectangle {
                            width: track.width
                            height: parent.height
                            gradient: Gradient {
                                orientation: Gradient.Horizontal
                                GradientStop {
                                    position: 0
                                    color: root.muted ? Colors.statusDanger : root.toneStart
                                }
                                GradientStop {
                                    position: 1
                                    color: root.fillColor
                                }
                            }
                        }
                    }
                }
            }

            Text {
                Layout.alignment: Qt.AlignVCenter
                text: root.percentLabel
                color: root.fillColor
                font.family: Constants.fontFamily
                font.pixelSize: Constants.fontSizeXs
                font.weight: Font.Medium
            }
        }
    }
}
