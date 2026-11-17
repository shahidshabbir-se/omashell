import QtQuick
import QtQuick.Layouts
import qs.common
import qs.config

RowLayout {
  id: root
  required property var playback
  spacing: MusicStyle.spacingLg

  Text {
    text: "󰕾"
    font.family: Constants.fontFamily
    font.pixelSize: MusicStyle.iconSizeLg
    color: Colors.accent
  }
  ValueSlider {
    Layout.fillWidth: true
    value: root.playback.volume
    maximum: root.playback.volumeMaximum || 1
    enabled: root.playback.canSetVolume
    onMoved: function(value) { root.playback.setVolume(value) }
  }
}
