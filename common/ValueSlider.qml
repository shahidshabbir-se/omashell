import QtQuick
import qs.config

// Draggable, wheel- and keyboard-adjustable value track: a thin rail, an accent
// fill and a knob. `adjust(±1)` is what the panel's keyboard navigation calls
// while the cursor sits on it.
Item {
  id: root

  property real value: 0
  property real minimum: 0
  property real maximum: 1
  property real step: 0.05
  property bool integer: false
  property bool navigable: true
  property bool hasCursor: false
  property color fillColor: Colors.accent
  property color railColor: Colors.muted

  signal moved(real value)

  readonly property real fraction: maximum > minimum
    ? Math.max(0, Math.min(1, (value - minimum) / (maximum - minimum)))
    : 0

  implicitHeight: 22

  function clamp(v) {
    var next = Math.max(root.minimum, Math.min(root.maximum, v))
    if (root.integer) next = Math.round(next)
    root.value = next
    root.moved(next)
  }

  function adjust(delta) {
    root.clamp(root.value + (delta * root.step))
  }

  function activate() {}

  Rectangle {
    id: rail

    anchors.verticalCenter: parent.verticalCenter
    anchors.left: parent.left
    anchors.right: parent.right
    height: 3
    radius: height / 2
    color: root.railColor
  }

  Rectangle {
    id: fill

    anchors.verticalCenter: rail.verticalCenter
    anchors.left: rail.left
    width: Math.round(rail.width * root.fraction)
    height: rail.height
    radius: rail.height / 2
    color: root.fillColor
  }

  Rectangle {
    id: knob

    anchors.verticalCenter: rail.verticalCenter
    x: Math.round(rail.width * root.fraction - width / 2)
    width: 10
    height: 10
    radius: height / 2
    color: root.fillColor
    border.width: root.hasCursor ? 2 : 0
    border.color: Colors.brightForeground
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor

    function setFromX(x) {
      var ratio = rail.width > 0 ? (x - rail.x) / rail.width : 0
      root.clamp(root.minimum + ratio * (root.maximum - root.minimum))
    }

    onPressed: function(mouse) { setFromX(mouse.x) }
    onPositionChanged: function(mouse) { if (pressed) setFromX(mouse.x) }
  }

  WheelHandler {
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: function(event) { root.adjust(event.angleDelta.y > 0 ? 1 : -1) }
  }
}
