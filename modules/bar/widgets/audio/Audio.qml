import QtQuick
import qs.common
import qs.config
import qs.modules.bar.widgets.audio

Item {
  id: root
  property string widgetId: ''
  property var settings: ({})
  property var screen: null
  readonly property string tooltip: settings && settings.showTooltip === true
    ? (AudioService.outputMuted ? 'Muted' : Math.round(AudioService.outputVolume * 100) + '%') : ''
  readonly property real barSlotWidth: Constants.iconSlot
  property real wheelRemainder: 0
  signal activated()
  implicitWidth: 21
  implicitHeight: 21

  OpticalGlyph {
    id: glyph
    anchors.fill: parent
    text: AudioService.icon
    fontSize: Constants.fontBody
    paintedSize: Constants.iconSize
    color: Colors.foreground
    scale: mouse.pressed ? 0.9 : 1
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.InOutQuad } }
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(event) {
      if (event.button === Qt.RightButton) AudioService.toggleAll()
      else root.activated()
    }
    onWheel: function(event) {
      root.wheelRemainder += event.angleDelta.y
      var steps = Math.trunc(root.wheelRemainder / 120)
      if (steps !== 0) {
        root.wheelRemainder -= steps * 120
        AudioService.setVolume(AudioService.sink, AudioService.outputVolume + steps * 0.05, 1)
      }
      event.accepted = true
    }
  }
}
