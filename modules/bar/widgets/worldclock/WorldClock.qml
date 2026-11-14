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

    Rectangle {
      anchors.fill: parent
      radius: Constants.cornerRadius
      color: mouse.containsMouse ? Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.08) : "transparent"

      Behavior on color {
        ColorAnimation {
          duration: 60
          easing.type: Easing.InOutQuad
        }
      }
    }

    OpticalGlyph {
      anchors.fill: parent
      text: "\uDB80\uDDE7"
      fontSize: Constants.fontBody
      // Fit the ink to the size the glyph had before: the centring changes, not the size.
      paintedSize: glyphSize
      color: Colors.foreground
    }
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.toggleRequested()
  }
}
