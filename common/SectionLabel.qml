import QtQuick
import qs.config

// Small-caps section header with an optional hairline rule.
// Our own version: no upstream dependency, tokens come from Constants/Colors.
Item {
  id: root

  property string text: ""
  property bool rule: false
  property color color: Colors.darkForeground

  implicitHeight: label.implicitHeight + (rule ? Constants.gap : 0)

  Text {
    id: label

    text: root.text.toUpperCase()
    color: root.color
    font.family: Constants.fontFamily
    font.pixelSize: Constants.fontCaption
    font.letterSpacing: 1
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    width: parent.width
    elide: Text.ElideRight
  }

  Rectangle {
    visible: root.rule
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 1
    color: Colors.muted
  }
}
