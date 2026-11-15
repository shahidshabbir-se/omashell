import QtQuick
import qs.config

Item {
  id: root

  property var deed: ({})
  property real rule: 1
  property color ruleColor: 'transparent'
  property bool leftRule: false
  signal activated()

  Rectangle {
    anchors.fill: parent
    anchors.topMargin: root.rule
    anchors.leftMargin: root.leftRule ? root.rule : 0
    color: mouse.containsMouse
      ? Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.08)
      : 'transparent'
    Behavior on color { ColorAnimation { duration: 120 } }
  }

  Rectangle { width: parent.width; height: root.rule; color: root.ruleColor }

  Rectangle {
    visible: root.leftRule
    anchors.left: parent.left
    anchors.top: parent.top
    anchors.bottom: parent.bottom
    width: root.rule
    color: root.ruleColor
  }

  Text {
    anchors.centerIn: parent
    anchors.verticalCenterOffset: root.rule / 2
    width: parent.width - 8
    horizontalAlignment: Text.AlignHCenter
    text: String(root.deed.text || '')
    color: mouse.containsMouse ? Colors.foreground : Qt.darker(Colors.foreground, 1.15)
    font.family: Constants.fontFamily
    font.pixelSize: Constants.fontBody
    elide: Text.ElideRight
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }
}
