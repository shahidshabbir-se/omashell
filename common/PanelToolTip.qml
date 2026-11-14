import QtQuick
import QtQuick.Controls
import qs.config

// Shared panel tooltip: plain foreground text on the shell tooltip surface,
// delayed like Omarchy's panel tips so it doesn't flash while moving the pointer.
ToolTip {
  id: root

  property color foreground: Colors.foreground
  property color backgroundColor: Colors.darkerBackground
  property string fontFamily: Constants.fontFamily
  property int fontSize: Constants.fontBodySmall

  delay: 400
  padding: 0

  background: Rectangle {
    color: root.backgroundColor
    border.width: 1
    border.color: Colors.muted
    radius: Constants.cornerRadius
  }

  contentItem: Text {
    text: root.text
    textFormat: Text.PlainText
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    leftPadding: 6
    rightPadding: 6
    topPadding: 3
    bottomPadding: 3
  }
}
