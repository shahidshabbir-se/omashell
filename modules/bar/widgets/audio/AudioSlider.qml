import QtQuick
import qs.config

Item {
  id: root
  property real value: 0
  property real maximum: 1
  property real liveValue: value
  property bool dragging: false
  property bool navigable: true
  property bool hasCursor: false
  property var panelNav: null
  property string navigationKey: ''
  signal moved(real value)
  signal muteRequested()
  readonly property real fraction: maximum > 0 ? Math.max(0, Math.min(1, liveValue / maximum)) : 0
  implicitHeight: 26
  onValueChanged: if (!dragging) liveValue = value
  function adjust(direction) { root.moved(Math.max(0, Math.min(maximum, value + direction * 0.05))) }
  function activate() { root.muteRequested() }
  function toggleMute() { root.muteRequested() }

  Rectangle {
    anchors.fill: parent
    visible: root.hasCursor
    color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.08)
    border.width: 1
    border.color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.25)
  }
  Item {
    id: trackArea
    anchors.fill: parent
    anchors.leftMargin: 13
    anchors.rightMargin: 13
    Rectangle {
      id: track
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      height: 4
      radius: Math.min(Constants.cornerRadius, height / 2)
      color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.18)
      Rectangle {
        width: parent.width * root.fraction
        height: parent.height
        radius: parent.radius
        color: Colors.foreground
      }
    }
    Rectangle {
      x: track.width * root.fraction - width / 2
      anchors.verticalCenter: parent.verticalCenter
      width: 14
      height: 14
      radius: Math.min(Constants.cornerRadius, height / 2)
      color: Colors.foreground
      border.width: 2
      border.color: Colors.background
      scale: mouse.containsMouse ? 1.15 : 1
      Behavior on scale { NumberAnimation { duration: 110 } }
    }
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onEntered: if (root.panelNav && root.navigable) root.panelNav.select(root)
    function moveTo(x) {
      var fraction = Math.max(0, Math.min(1, (x - trackArea.x) / Math.max(1, trackArea.width)))
      root.liveValue = fraction * root.maximum
      root.moved(root.liveValue)
    }
    onPressed: function(event) {
      if (event.button === Qt.LeftButton) { root.dragging = true; moveTo(event.x) }
    }
    onPositionChanged: function(event) { if (root.dragging) moveTo(event.x) }
    onReleased: function(event) {
      if (event.button === Qt.LeftButton) { root.dragging = false; root.liveValue = root.value }
    }
    onClicked: function(event) { if (event.button === Qt.RightButton) root.muteRequested() }
    onWheel: function(event) { root.adjust(event.angleDelta.y > 0 ? 1 : -1); event.accepted = true }
  }
}
