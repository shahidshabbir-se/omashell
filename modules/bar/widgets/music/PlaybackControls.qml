import QtQuick
import QtQuick.Layouts
import "../../../../config"

RowLayout {
    id: root

    required property var playback
    required property bool entranceReady

    readonly property int animationDuration: 140

    spacing: MusicStyle.spacingXl
    opacity: entranceReady ? 1 : 0

    transform: Translate {
        y: root.entranceReady ? 0 : 16

        Behavior on y {
            NumberAnimation {
                duration: 460
                easing.type: Easing.OutCubic
            }
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: 420
            easing.type: Easing.OutCubic
        }
    }

    Item {
        Layout.preferredWidth: 28
        Layout.preferredHeight: MusicStyle.musicPrimaryControlSize
        scale: shufflePointer.pressed ? 0.86 : shufflePointer.containsMouse ? 1.08 : 1

        Behavior on scale {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.OutCubic
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.playback.shuffleSupported
            text: "󰒟"
            font.family: Constants.fontFamily
            font.pixelSize: 18
            color: root.playback.shuffleActive ? Colors.accent : Colors.foreground
            opacity: root.playback.shuffleActive ? 1 : 0.62

            Behavior on opacity {
                NumberAnimation {
                    duration: root.animationDuration
                }
            }
        }

        MouseArea {
            id: shufflePointer

            anchors.fill: parent
            enabled: root.playback.canToggleShuffle
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.playback.toggleShuffle()
        }
    }

    Item {
        Layout.fillWidth: true
    }

    Rectangle {
        Layout.preferredWidth: MusicStyle.musicControlSize
        Layout.preferredHeight: MusicStyle.musicControlSize
        radius: width / 2
        scale: previousPointer.pressed ? 0.86 : previousPointer.containsMouse ? 1.06 : 1
        color: previousPointer.containsMouse ? MusicStyle.selectionSurface : MusicStyle.backgroundRaised

        Behavior on scale {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.OutCubic
            }
        }

        Text {
            anchors.centerIn: parent
            text: "󰒮"
            font.family: Constants.fontFamily
            font.pixelSize: 18
            color: MusicStyle.foregroundStrong
        }

        MouseArea {
            id: previousPointer

            anchors.fill: parent
            enabled: root.playback.canGoPrevious
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.playback.goPrevious()
        }
    }

    Rectangle {
        Layout.preferredWidth: MusicStyle.musicPrimaryControlSize
        Layout.preferredHeight: MusicStyle.musicPrimaryControlSize
        radius: width / 2
        scale: playPointer.pressed ? 0.88 : playPointer.containsMouse ? 1.08 : 1
        color: playPointer.containsMouse ? MusicStyle.accentHover : Colors.accent

        Behavior on scale {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.OutCubic
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.playback.isPlaying ? "󰏤" : "󰐊"
            font.family: Constants.fontFamily
            font.pixelSize: 20
            color: Colors.background
        }

        MouseArea {
            id: playPointer

            anchors.fill: parent
            enabled: root.playback.canTogglePlaying
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.playback.togglePlaying()
        }
    }

    Rectangle {
        Layout.preferredWidth: MusicStyle.musicControlSize
        Layout.preferredHeight: MusicStyle.musicControlSize
        radius: width / 2
        scale: nextPointer.pressed ? 0.86 : nextPointer.containsMouse ? 1.06 : 1
        color: nextPointer.containsMouse ? MusicStyle.selectionSurface : MusicStyle.backgroundRaised

        Behavior on scale {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.OutCubic
            }
        }

        Text {
            anchors.centerIn: parent
            text: "󰒭"
            font.family: Constants.fontFamily
            font.pixelSize: 18
            color: MusicStyle.foregroundStrong
        }

        MouseArea {
            id: nextPointer

            anchors.fill: parent
            enabled: root.playback.canGoNext
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.playback.goNext()
        }
    }

    Item {
        Layout.fillWidth: true
    }

    Item {
        Layout.preferredWidth: 28
        Layout.preferredHeight: MusicStyle.musicPrimaryControlSize
        scale: repeatPointer.pressed ? 0.86 : repeatPointer.containsMouse ? 1.08 : 1

        Behavior on scale {
            NumberAnimation {
                duration: root.animationDuration
                easing.type: Easing.OutCubic
            }
        }

        Text {
            anchors.centerIn: parent
            visible: root.playback.loopSupported
            text: "󰑖"
            font.family: Constants.fontFamily
            font.pixelSize: 18
            color: root.playback.loopActive ? Colors.accent : Colors.foreground
            opacity: root.playback.loopActive ? 1 : 0.62

            Behavior on opacity {
                NumberAnimation {
                    duration: root.animationDuration
                }
            }
        }

        MouseArea {
            id: repeatPointer

            anchors.fill: parent
            enabled: root.playback.canToggleLoop
            hoverEnabled: true
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: root.playback.toggleLoop()
        }
    }
}
