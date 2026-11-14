import QtQuick
import qs.config

// Small-caps section header with an optional hairline rule.
// Our own version: no upstream dependency, tokens come from Constants/Colors.
Item {
  id: root

  property string text: ""
  property bool rule: false
  property color color: Qt.darker(Colors.foreground, 1.4)

  implicitHeight: Math.ceil(label.implicitHeight) + (rule ? Constants.gap : 0)

  Text {
    id: label

    text: root.text.toUpperCase()
    color: root.color
    font.family: Constants.fontFamily
    font.pixelSize: Constants.fontCaption
    font.bold: true
    // Glyphs overshoot their ascent in nerd fonts; a header at the top of a
    // clipping list loses that sliver and renders beheaded. Reserve it.
    topPadding: Math.ceil(font.pixelSize * 0.15)
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
