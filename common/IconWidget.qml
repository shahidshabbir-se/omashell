import QtQuick
import qs.config

// An icon-only bar widget: one glyph fitted to the bar's icon size, drawn on a
// 21px canvas and given a full icon slot to sit in.
//
// Everything here was previously repeated in Weather, WorldClock and the kit demo:
// canvas size, slot footprint, open-panel mark width, press scale, hover feedback.
// Widgets now supply state and one activated() signal.
Widget {
  id: root

  property string glyph: ""
  // Tints the glyph accent, for a widget reporting an on/in-use state.
  property bool active: false
  // Hover text; the bar hosts it (a masked layer surface cannot draw above itself).
  property string tooltip: ""

  readonly property int canvas: 21
  // Ink height the glyph is fitted to, so its outline sits on the slot's centre
  // rather than on a line box.
  property real glyphSize: Constants.iconSize

  signal activated()

  // Hint for the bar's open-panel mark: underline the ink, not the box around it.
  readonly property real openPanelIndicatorWidth: glyphItem.paintedWidth
  // Icon widgets take the icon slot instead of content + padding.
  readonly property real barSlotWidth: Constants.iconSlot

  implicitWidth: canvas
  implicitHeight: canvas

  Item {
    id: visual

    anchors.fill: parent
    scale: mouse.pressed ? 0.9 : 1

    Behavior on scale {
      NumberAnimation {
        duration: 80
        easing.type: Easing.InOutQuad
      }
    }

    OpticalGlyph {
      id: glyphItem

      anchors.fill: parent
      text: root.glyph
      fontSize: Constants.fontBody
      paintedSize: root.glyphSize
      color: root.active ? Colors.accent : Colors.foreground
    }
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }
}
