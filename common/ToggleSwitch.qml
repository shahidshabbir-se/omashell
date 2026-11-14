import QtQuick
import qs.config

// Bare on/off switch: a track with a sliding knob and no label.
//
// Monochrome on purpose - the track and knob are drawn from `foreground` at set
// alphas, so the switch follows the bar's text colour instead of competing with
// the accent (accent is reserved for the open-panel mark and focus rings).
//
// One number sets the size: `trackHeight`. Width, knob size and knob inset are
// derived from it, so a compact placement can shrink the whole control instead of
// scaling a big one down - scaling lands the track and knob on fractional pixels
// and blurs their edges.
//
// The track has no border of its own. The only outline is the keyboard-focus ring,
// drawn outside the track in the space this control reserves for it.
Item {
  id: root

  property bool checked: false
  property bool busy: false
  property bool navigable: true
  property bool hasCursor: false
  property var panelNav: null
  property string navigationKey: ""

  property color foreground: Colors.foreground

  // Room for the keyboard-focus ring on each side.
  property int cursorPad: 6

  // Follow the theme, not our taste: sharp when the theme has no corner radius.
  // (Constants.cornerRadius is 0 here, so the switch renders square, which is what
  // the same theme does on the other side.)
  property bool rounded: Constants.cornerRadius > 0

  property int trackHeight: 22
  property int trackWidth: Math.round(trackHeight * 1.9)
  property int knobSize: Math.max(6, Math.round(trackHeight * 0.72))
  property int knobInset: Math.max(1, Math.round((trackHeight - knobSize) / 2))

  signal toggled()
  readonly property bool containsMouse: mouse.containsMouse

  implicitWidth: root.trackWidth + root.cursorPad * 2
  implicitHeight: root.trackHeight + root.cursorPad * 2

  function activate() {
    if (root.busy) return
    // The caller owns checked state; preserve its binding to the adapter.
    root.toggled()
  }

  // Keyboard focus only: hovering does not draw it.
  Rectangle {
    anchors.fill: parent
    visible: root.hasCursor
    color: "transparent"
    radius: root.rounded ? Math.min(width, height) / 2 : 0
    border.width: 1
    border.color: root.shade(0.25)
  }

  // Foreground at an alpha, so the whole switch stays in one colour.
  function shade(alpha) {
    return Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, alpha)
  }

  Rectangle {
    id: track

    width: root.trackWidth
    height: root.trackHeight
    anchors.centerIn: parent
    radius: root.rounded ? height / 2 : 0
    // Match Omarchy's normal/selected chrome: a faint off track with an idle
    // outline, then the stronger foreground fill when enabled.
    color: root.checked ? root.shade(0.18) : root.shade(0.04)
    border.width: root.checked ? 0 : 1
    border.color: root.shade(0.4)

    Behavior on color {
      ColorAnimation { duration: 120 }
    }

    Rectangle {
      id: knob

      width: root.knobSize
      height: root.knobSize
      radius: root.rounded ? height / 2 : 0
      anchors.verticalCenter: parent.verticalCenter
      x: root.checked ? track.width - width - root.knobInset : root.knobInset
      color: root.checked ? root.foreground : Qt.darker(root.foreground, 1.25)

      Behavior on x {
        NumberAnimation {
          duration: 120
          easing.type: Easing.OutCubic
        }
      }

      Behavior on color {
        ColorAnimation { duration: 120 }
      }
    }
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: if (root.panelNav) root.panelNav.select(root)
    onClicked: root.activate()
  }
}
