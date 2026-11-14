import QtQuick
import qs.config

// Two-state switch. Drawn as a pill track with a knob, not as a Qt control, so it
// matches the bar: no platform style, our own tokens, and a ring when the panel's
// keyboard navigation has the cursor on it.
Item {
  id: root

  property bool checked: false
  property bool busy: false
  property bool navigable: true
  property bool hasCursor: false
  property color accent: Colors.accent
  property color trackColor: Colors.muted

  signal toggled()

  readonly property int trackWidth: 34
  readonly property int trackHeight: 18
  readonly property int knobSize: trackHeight - 4

  implicitWidth: trackWidth
  implicitHeight: trackHeight + (hasCursor ? 6 : 0)

  function activate() {
    if (root.busy) return
    root.checked = !root.checked
    root.toggled()
  }

  Rectangle {
    id: track

    anchors.centerIn: parent
    width: root.trackWidth
    height: root.trackHeight
    radius: height / 2
    color: root.checked ? root.accent : root.trackColor
    border.width: root.hasCursor ? 2 : 0
    border.color: root.hasCursor ? Colors.brightForeground : "transparent"

    Behavior on color {
      ColorAnimation { duration: 120 }
    }

    Rectangle {
      id: knob

      width: root.knobSize
      height: root.knobSize
      radius: height / 2
      y: (parent.height - height) / 2
      x: root.checked ? parent.width - width - 2 : 2
      color: root.checked ? Colors.background : Colors.darkForeground

      Behavior on x {
        NumberAnimation { duration: 130; easing.type: Easing.OutCubic }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activate()
  }
}
