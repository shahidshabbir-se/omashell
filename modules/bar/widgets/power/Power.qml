import QtQuick
import qs.common
import qs.config
import qs.modules.bar.widgets.power

Item {
  id: root
  property string widgetId: ''
  property var settings: ({})
  property var screen: null
  readonly property string tooltip: settings && settings.showTooltip === true && PowerService.present
    ? PowerService.mode + ' · ' + Math.round(PowerService.fraction * 100) + '%'
    : ''
  readonly property real barSlotWidth: PowerService.showPercentage ? Constants.iconSlot * 2 : Constants.iconSlot
  signal activated()

  readonly property bool available: PowerService.present
  visible: available
  implicitWidth: barSlotWidth
  implicitHeight: Constants.barHeight

  Row {
    id: contents
    anchors.centerIn: parent
    spacing: 4
    scale: mouse.pressed ? 0.9 : 1
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.InOutQuad } }
    Text {
      visible: PowerService.showPercentage
      text: Math.round(PowerService.fraction * 100) + '%'
      color: Colors.foreground
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontBody
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
    }
    Item {
      width: 16
      height: 16
      anchors.verticalCenter: parent.verticalCenter
      OpticalGlyph {
        id: glyph
        anchors.fill: parent
        text: PowerService.icon
        fontSize: Constants.fontBody
        paintedSize: Constants.iconSize
        color: Colors.foreground
      }
    }
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(event) {
      if (event.button === Qt.RightButton) PowerService.togglePercentage()
      else root.activated()
    }
  }
}
