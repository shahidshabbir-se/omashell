import QtQuick
import qs.config

// Clickable label button for panel actions. Kept deliberately plain: a border on
// hover, an accent border while the keyboard cursor sits on it.
Item {
  id: root

  property string text: ""
  property bool navigable: true
  property bool hasCursor: false
  property bool accented: false

  signal activated()

  implicitWidth: label.implicitWidth + Constants.panelPadding * 2
  implicitHeight: 26

  function activate() {
    root.activated()
  }

  Rectangle {
    anchors.fill: parent
    radius: Constants.cornerRadius
    color: mouse.containsMouse ? Colors.lighterBackground : "transparent"
    border.width: root.hasCursor || root.accented ? 1 : 0
    border.color: root.accented ? Colors.accent : Colors.brightForeground

    Text {
      id: label

      anchors.centerIn: parent
      text: root.text
      color: Colors.foreground
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontBody
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
    }
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activate()
  }
}
