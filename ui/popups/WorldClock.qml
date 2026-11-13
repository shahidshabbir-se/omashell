import QtQuick
import qs.config
import qs.providers
import qs.ui.components

PopupShell {
  id: root

  layerNamespace: "omashell-world-clock"
  cardWidth: 340
  spacing: 14

  onOpenedChanged: if (opened) globeSpin.restart()

  function rowFill(offset, hovered) {
    var alpha = WorldClockProvider.phaseFill(offset) + (hovered ? 0.05 : 0)
    return Qt.rgba(
      Colors.background.r + (Colors.foreground.r - Colors.background.r) * alpha,
      Colors.background.g + (Colors.foreground.g - Colors.background.g) * alpha,
      Colors.background.b + (Colors.foreground.b - Colors.background.b) * alpha,
      1)
  }

  Column {
    width: parent.width
    spacing: 2

    ArcText {
      width: parent.width
      text: WorldClockProvider.caption
      rise: 6
      pixelSize: Constants.fontCaption
      fontFamily: Constants.fontFamily
      color: Qt.darker(Colors.foreground, 1.55)
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 9

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "World"
        textFormat: Text.PlainText
        color: Colors.foreground
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontTitle
        font.weight: Font.DemiBold
      }

      MiniGlobe {
        id: heroGlobe
        anchors.verticalCenter: parent.verticalCenter
        width: 31
        height: 31
        color: Colors.foreground
        bold: true
        showMarker: true
        markerLat: 24.86
        markerLon: 67.01
        markerColor: Colors.accent
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Clock"
        textFormat: Text.PlainText
        color: Colors.foreground
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontTitle
        font.weight: Font.DemiBold
      }
    }
  }

  property NumberAnimation globeSpin: NumberAnimation {
    id: globeSpin
    target: heroGlobe
    property: "spin"
    from: 67.01 - 1080
    to: 67.01
    duration: root.duration(1250)
    easing.type: Easing.OutQuart
  }

  Column {
    width: parent.width
    spacing: 6

    Repeater {
      model: WorldClockProvider.rows

      Rectangle {
        id: cityRow

        required property var modelData

        readonly property var offset: modelData.offset
        readonly property bool ready: offset !== undefined && offset !== null
        readonly property bool lit: WorldClockProvider.isLit(offset)

        width: parent.width
        height: 69
        radius: Constants.cornerRadius
        color: root.rowFill(offset, rowHover.hovered)

        HoverHandler { id: rowHover }

        Column {
          id: rowLabels

          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.right: timeBlock.left
          anchors.rightMargin: 10
          anchors.top: parent.top
          anchors.topMargin: 12
          spacing: 2

          Text {
            width: parent.width
            elide: Text.ElideRight
            text: modelData.label
            textFormat: Text.PlainText
            color: Colors.foreground
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontSubtitle
            font.weight: Font.DemiBold
          }

          Item {
            width: parent.width
            height: dateRow.height

            Row {
              id: dateRow
              spacing: 4
              opacity: rowHover.hovered ? 0 : 1
              visible: opacity > 0

              Behavior on opacity {
                NumberAnimation { duration: root.duration(110) }
              }

              Text {
                text: ready ? WorldClockProvider.dateAt(offset) : "\u2026"
                textFormat: Text.PlainText
                color: Qt.darker(Colors.foreground, 1.55)
                font.family: Constants.fontFamily
                font.pixelSize: Constants.fontCaption
              }

              Text {
                visible: ready && WorldClockProvider.dayLabel(offset) !== ""
                text: "\u00B7"
                textFormat: Text.PlainText
                color: Qt.darker(Colors.foreground, 2.1)
                font.family: Constants.fontFamily
                font.pixelSize: Constants.fontCaption
              }

              Text {
                visible: ready && WorldClockProvider.dayLabel(offset) !== ""
                text: ready ? WorldClockProvider.dayLabel(offset) : ""
                textFormat: Text.PlainText
                color: Qt.darker(Colors.foreground, 1.55)
                font.family: Constants.fontFamily
                font.pixelSize: Constants.fontCaption
              }
            }

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: WorldClockProvider.greeting(offset)
              opacity: rowHover.hovered ? 1 : 0
              visible: opacity > 0
              textFormat: Text.PlainText
              color: Colors.foreground
              font.family: Constants.fontFamily
              font.pixelSize: Constants.fontCaption

              Behavior on opacity {
                NumberAnimation { duration: root.duration(110) }
              }
            }
          }
        }

        Column {
          id: timeBlock

          width: 58
          anchors.right: parent.right
          anchors.rightMargin: 12
          anchors.verticalCenter: rowLabels.verticalCenter
          spacing: 1

          Text {
            anchors.right: parent.right
            text: ready ? WorldClockProvider.timeAt(offset) : "--:--"
            textFormat: Text.PlainText
            color: Colors.foreground
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontHeading
            font.weight: Font.DemiBold
          }

          Text {
            anchors.right: parent.right
            visible: ready
            text: modelData.abbr + " " + WorldClockProvider.offsetLabel(offset)
            textFormat: Text.PlainText
            color: Qt.darker(Colors.foreground, 2.1)
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontCaption
          }
        }

        Rectangle {
          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.right: parent.right
          anchors.rightMargin: 12
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 15
          height: 3
          radius: height / 2
          color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.10)

          Rectangle {
            x: parent.width * 0.25
            width: parent.width * 0.5
            height: parent.height
            radius: parent.radius
            color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.28)
          }

          Rectangle {
            x: Math.round(parent.width * WorldClockProvider.progressAt(offset) - 4)
            y: (parent.height - height) / 2
            width: 8
            height: 8
            radius: 4
            color: lit ? "#E5C736" : "transparent"
            border.width: lit ? 0 : 1
            border.color: Colors.foreground

            Behavior on x {
              NumberAnimation {
                duration: root.duration(400)
                easing.type: Easing.OutCubic
              }
            }
          }
        }
      }
    }
  }
}
