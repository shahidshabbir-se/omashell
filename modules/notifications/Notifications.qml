import QtQuick
import qs.common
import qs.config
import qs.modules.notifications

Item {
  id: root

  property string widgetId: ''
  property var settings: ({})
  property var screen: null

  readonly property string glyph: NotificationService.live.length > 0
    ? '󰂚'
    : (NotificationService.dnd ? '󰂛' : '󰂜')
  readonly property color tint: NotificationService.live.length > 0 ? Colors.accent
    : (NotificationService.dnd ? Colors.darkForeground : Colors.foreground)
  readonly property string tooltip: settings && settings.showTooltip === true
    ? (NotificationService.dnd ? 'Do not disturb' : NotificationService.live.length + ' unread')
    : ''
  readonly property real barSlotWidth: Constants.iconSlot
  signal activated()

  implicitWidth: 21
  implicitHeight: 21

  Item {
    id: visual
    anchors.fill: parent
    scale: mouse.pressed ? 0.9 : 1
    Behavior on scale { NumberAnimation { duration: 80; easing.type: Easing.InOutQuad } }

    OpticalGlyph {
      id: glyphItem
      anchors.fill: parent
      text: root.glyph
      fontSize: Constants.fontBody
      paintedSize: Constants.iconSize
      color: root.tint
      Behavior on color { ColorAnimation { duration: 150 } }
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    onClicked: function(event) {
      if (event.button === Qt.RightButton) NotificationService.toggleDnd()
      else root.activated()
    }
  }
}
