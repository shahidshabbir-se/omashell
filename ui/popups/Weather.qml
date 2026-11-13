import QtQuick
import qs.config
import qs.providers
import qs.ui.components

PopupShell {
  id: root

  layerNamespace: "omashell-weather"
  cardWidth: 560
  spacing: 14

  onOpenedChanged: if (opened) WeatherProvider.refreshIfStale()

  Item {
    width: parent.width
    height: Math.max(heroLeft.height, heroRight.height)

    Row {
      id: heroLeft
      anchors.left: parent.left
      anchors.leftMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      spacing: 16

      Text {
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: 5
        text: WeatherProvider.glyph
        textFormat: Text.PlainText
        color: Colors.foreground
        font.family: Constants.fontFamily
        font.pixelSize: 64
      }

      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Text {
          id: tempBig
          text: WeatherProvider.tempNumber || "\u2014"
          textFormat: Text.PlainText
          color: Colors.foreground
          font.family: Constants.fontFamily
          font.pixelSize: 56
          font.bold: true
        }

        Text {
          anchors.top: tempBig.top
          anchors.topMargin: 10
          text: WeatherProvider.tempUnit
          textFormat: Text.PlainText
          color: Colors.foreground
          font.family: Constants.fontFamily
          font.pixelSize: Constants.fontDisplay
        }
      }
    }

    Column {
      id: heroRight
      width: weatherStats.implicitWidth
      anchors.right: parent.right
      anchors.rightMargin: 20
      anchors.verticalCenter: parent.verticalCenter
      spacing: 12

      Row {
        visible: WeatherProvider.locationName !== ""
        spacing: 6

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: "\uF041"
          textFormat: Text.PlainText
          color: Qt.darker(Colors.foreground, 1.4)
          font.family: Constants.fontFamily
          font.pixelSize: Constants.fontBody
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: WeatherProvider.locationName.toUpperCase()
          textFormat: Text.PlainText
          color: Qt.darker(Colors.foreground, 1.4)
          font.family: Constants.fontFamily
          font.pixelSize: Constants.fontBody
          font.letterSpacing: 1
        }
      }

      Row {
        id: weatherStats
        visible: WeatherProvider.current !== null
        spacing: 36

        Column {
          spacing: 5

          Text {
            text: "FEELS"
            textFormat: Text.PlainText
            color: Qt.darker(Colors.foreground, 1.5)
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontBodySmall
            font.letterSpacing: 1
          }

          Text {
            text: WeatherProvider.feelsText
            textFormat: Text.PlainText
            color: Colors.foreground
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontTitle
          }
        }

        Column {
          spacing: 5

          Text {
            text: "WIND"
            textFormat: Text.PlainText
            color: Qt.darker(Colors.foreground, 1.5)
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontBodySmall
            font.letterSpacing: 1
          }

          Text {
            text: WeatherProvider.windText
            textFormat: Text.PlainText
            color: Colors.foreground
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontTitle
          }
        }

        Column {
          spacing: 5

          Text {
            text: "HUMID"
            textFormat: Text.PlainText
            color: Qt.darker(Colors.foreground, 1.5)
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontBodySmall
            font.letterSpacing: 1
          }

          Text {
            text: WeatherProvider.humidityText
            textFormat: Text.PlainText
            color: Colors.foreground
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontTitle
          }
        }
      }
    }
  }

  Text {
    visible: WeatherProvider.current === null
    text: "Fetching forecast\u2026"
    textFormat: Text.PlainText
    color: Qt.darker(Colors.foreground, 1.5)
    font.family: Constants.fontFamily
    font.pixelSize: Constants.fontBodySmall
    font.italic: true
  }

  Rectangle {
    visible: WeatherProvider.forecast.length > 0
    width: parent.width
    height: 1
    color: Colors.foreground
    opacity: 0.12
  }

  Item {
    visible: WeatherProvider.forecast.length > 0
    width: parent.width
    height: forecastRow.height

    Row {
      id: forecastRow
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 44

      Repeater {
        model: WeatherProvider.forecast

        Row {
          required property var modelData
          spacing: 10

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.glyph
            textFormat: Text.PlainText
            color: Colors.foreground
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontDisplay
          }

          Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Text {
              text: modelData.label
              textFormat: Text.PlainText
              color: Qt.darker(Colors.foreground, 1.4)
              font.family: Constants.fontFamily
              font.pixelSize: Constants.fontCaption
              font.letterSpacing: 1
            }

            Row {
              spacing: 6

              Text {
                text: modelData.high
                textFormat: Text.PlainText
                color: Colors.foreground
                font.family: Constants.fontFamily
                font.pixelSize: Constants.fontBody
              }

              Text {
                text: modelData.low
                textFormat: Text.PlainText
                color: Qt.darker(Colors.foreground, 1.5)
                font.family: Constants.fontFamily
                font.pixelSize: Constants.fontBody
              }
            }
          }
        }
      }
    }
  }
}
