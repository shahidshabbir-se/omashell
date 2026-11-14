import QtQuick
import qs.common
import qs.config

Item {
  id: root

  implicitWidth: 21
  implicitHeight: 21

  // Ink height the glyph is fitted to, so its outline sits on the slot's centre
  // instead of on a line box.
  property real glyphSize: Constants.iconSize

  // Hint for the bar's open-panel mark: underline the icon's ink, not the 21px
  // box around it. Same property name Omarchy uses for the same purpose.
  readonly property real openPanelIndicatorWidth: glyph.paintedWidth

  // Icon-only widgets take the bar's icon slot instead of content + padding, which
  // leaves 7.5px of air around the 12px ink, the way Omarchy's icon buttons sit.
  readonly property real barSlotWidth: Constants.iconSlot

  signal toggleRequested()

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
      id: glyph
      anchors.fill: parent
      text: "\uDB80\uDDE7"
      fontSize: Constants.fontBody
      paintedSize: root.glyphSize
      color: Colors.foreground
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggleRequested()
  }
}
