import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../../../../config"
import "."

ColumnLayout {
    id: root

    required property var playback
    required property bool entranceReady
    required property bool panelOpen

    readonly property bool hasRealArtwork: root.playback.hasCurrentPlayback && root.playback.hasPlayer && !!root.playback.player && !!root.playback.player.trackArtUrl && String(root.playback.player.trackArtUrl).length > 0

    spacing: 0

    Text {
        Layout.fillWidth: true
        visible: root.playback.hasCurrentPlayback
        text: "Now Playing"
        horizontalAlignment: Text.AlignHCenter
        color: MusicStyle.foregroundStrong
        font.family: Constants.fontFamily
        font.pixelSize: MusicStyle.fontSizeLg
        font.weight: Font.DemiBold
        opacity: root.entranceReady ? 1 : 0

        transform: Translate {
            y: root.entranceReady ? 0 : -6

            Behavior on y {
                NumberAnimation {
                    duration: 340
                    easing.type: Easing.OutCubic
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 320
                easing.type: Easing.OutCubic
            }
        }
    }

    Item {
        Layout.preferredHeight: root.playback.hasCurrentPlayback ? MusicStyle.spacingLg : 0
    }

    ClippingRectangle {
        id: artworkContainer

        Layout.preferredWidth: Math.min(MusicStyle.musicArtworkSize, root.width)
        Layout.preferredHeight: Math.min(MusicStyle.musicArtworkSize, root.width)
        Layout.alignment: Qt.AlignHCenter
        radius: width / 2
        color: "transparent"
        opacity: root.entranceReady ? 1 : 0
        scale: root.entranceReady ? 1 : 0.88

        Behavior on opacity {
            NumberAnimation {
                duration: 350
                easing.type: Easing.OutCubic
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 500
                easing.type: Easing.OutBack
                easing.overshoot: 0.6
            }
        }

        VinylDisc {
            visible: !root.hasRealArtwork
            isPlaying: root.playback.isPlaying
            hovered: discMouse.containsMouse
        }

        Image {
            anchors.fill: parent
            visible: root.hasRealArtwork
            source: root.playback.artworkSource
            sourceSize: Qt.size(MusicStyle.musicArtworkSize, MusicStyle.musicArtworkSize)
            fillMode: Image.PreserveAspectCrop
            smooth: true
            mipmap: true
        }

        MouseArea {
            id: discMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.playback.togglePlaying()
        }
    }

    property real discRotation: 0

    NumberAnimation {
        target: artworkContainer
        property: "rotation"
        from: root.discRotation
        to: root.discRotation + 360
        duration: root.playback.isPlaying ? 18000 : 45000
        loops: Animation.Infinite
        running: root.panelOpen
        onStopped: root.discRotation = artworkContainer.rotation
    }

    Item {
        Layout.preferredHeight: MusicStyle.spacingMd
    }

    Item {
        Layout.fillWidth: true
        Layout.preferredHeight: metadataColumn.implicitHeight
        opacity: root.entranceReady ? 1 : 0

        transform: Translate {
            y: root.entranceReady ? 0 : 12

            Behavior on y {
                NumberAnimation {
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 360
                easing.type: Easing.OutCubic
            }
        }

        ColumnLayout {
            id: metadataColumn

            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 2

            MarqueeText {
                Layout.fillWidth: true
                active: root.entranceReady
                text: root.playback.title
                color: MusicStyle.foregroundStrong
                font.family: Constants.fontFamily
                font.pixelSize: MusicStyle.fontSizeXl
                font.bold: true
            }

            MarqueeText {
                Layout.fillWidth: true
                active: root.entranceReady
                text: root.playback.artist
                color: MusicStyle.foregroundQuiet
                font.family: Constants.fontFamily
                font.pixelSize: MusicStyle.fontSizeMd
            }
        }
    }
}
