import QtQuick
import qs.config

Text {
  id: root

  signal calendarToggleRequested()

  font.family: Constants.fontFamily
  font.pixelSize: Constants.fontBody
  color: Colors.foreground

  property var formats: [
    "dddd HH:mm",
    "dddd h:mm AP",
    "dddd HH:mm:ss",
    "dddd h:mm:ss AP",
    "HH:mm",
    "h:mm AP",
    "ddd d MMM HH:mm",
    "ddd d MMM h:mm AP",
    "d MMMM 'W'ww yyyy",
    "yyyy-MM-dd HH:mm"
  ]

  property int formatIndex: 0
  property var currentDate: new Date()

  function isoWeekNumber(date) {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()))
    const day = d.getUTCDay() || 7
    d.setUTCDate(d.getUTCDate() + 4 - day)
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
    const week = Math.ceil(((d - yearStart) / 86400000 + 1) / 7)
    return week < 10 ? "0" + week : String(week)
  }

  text: formatIndex === 8
    ? Qt.formatDateTime(currentDate, "d MMMM")
      + " W" + isoWeekNumber(currentDate)
      + " " + Qt.formatDateTime(currentDate, "yyyy")
    : Qt.formatDateTime(currentDate, formats[formatIndex])

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.currentDate = new Date()
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor

    onClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton) root.calendarToggleRequested()
      else if (mouse.button === Qt.RightButton)
        root.formatIndex = (root.formatIndex + 1) % root.formats.length
    }
  }
}
