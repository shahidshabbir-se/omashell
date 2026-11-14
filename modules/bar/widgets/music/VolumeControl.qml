import QtQuick
import QtQuick.Layouts
import "../../../../config"
import "../audio"

RowLayout {
    id: root

    required property var playback

    spacing: Constants.spacingLg

    readonly property real maximumVolume: root.playback.volumeMaximum || 1

    Text {
        text: "󰕾"
        font.family: Constants.fontFamily
        font.pixelSize: Constants.iconSizeLg
        color: Colors.accent
    }

    VolumeSlider {
        Layout.fillWidth: true
        value: root.playback.volume
        maximumValue: root.maximumVolume
        interactive: root.playback.canSetVolume
        onMoved: value => root.playback.setVolume(value)
    }
}
