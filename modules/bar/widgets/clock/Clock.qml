import QtQuick
import qs.common
import qs.config

// Date/time label for the bar. Identity comes from the Widget base (so
// shell.json can seed a format), the glyph centring from OpticalText, and the
// right-click format cycling stays here because it is this widget's behaviour.
Widget {
  id: root

  signal calendarToggleRequested()

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

  // Seeded from shell.json ({"id": "clock", "format": 3}); right click cycles it.
  property int formatIndex: setting("format", 0)
  property var currentDate: new Date()

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  function isoWeekNumber(date) {
    const d = new Date(Date.UTC(date.getFullYear(), date.getMonth(), date.getDate()))
    const day = d.getUTCDay() || 7
    d.setUTCDate(d.getUTCDate() + 4 - day)
    const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1))
    const week = Math.ceil(((d - yearStart) / 86400000 + 1) / 7)
    return week < 10 ? "0" + week : String(week)
  }

  OpticalText {
    id: label

    anchors.centerIn: parent
    text: root.formatIndex === 8
      ? Qt.formatDateTime(root.currentDate, "d MMMM")
        + " W" + root.isoWeekNumber(root.currentDate)
        + " " + Qt.formatDateTime(root.currentDate, "yyyy")
      : Qt.formatDateTime(root.currentDate, root.formats[root.formatIndex])
    pixelSize: Constants.fontBody
    color: Colors.foreground
  }

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
