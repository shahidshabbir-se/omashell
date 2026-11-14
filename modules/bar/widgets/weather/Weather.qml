import QtQuick
import qs.config
import qs.modules.bar.widgets.weather

Item {
  id: root

  implicitWidth: 21
  implicitHeight: 21

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

    Text {
      anchors.centerIn: parent
      text: WeatherService.glyph
      textFormat: Text.PlainText
      color: Colors.foreground
      font.family: Constants.fontFamily
      font.pixelSize: 13
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
