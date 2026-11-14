import QtQuick
import "../../../../config"

// Compact slider adapter retained for the music popup and volume controls.
Item {
    id: root
    property real value: 0
    property real maximumValue: 1
    property real step: 0.05
    property bool interactive: true
    signal moved(real value)
    readonly property real shownValue: Math.max(0, Math.min(maximumValue, dragging ? pendingValue : value))
    property bool dragging: false
    property real pendingValue: value
    implicitHeight: 26

    function updateAt(x) {
        var v = width > 0 ? Math.max(0, Math.min(maximumValue, x / width * maximumValue)) : 0
        if (step > 0) v = Math.round(v / step) * step
        pendingValue = v
        moved(v)
    }

    Rectangle {
        id: track
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        height: 4
        radius: 2
        color: Colors.withAlpha(Colors.foregroundStrong, 0.2)
        Rectangle {
            width: parent.width * (root.maximumValue > 0 ? root.shownValue / root.maximumValue : 0)
            height: parent.height
            radius: parent.radius
            color: Colors.foregroundStrong
        }
    }
    Rectangle {
        x: track.x + track.width * (root.maximumValue > 0 ? root.shownValue / root.maximumValue : 0) - width / 2
        anchors.verticalCenter: track.verticalCenter
        width: 12
        height: 12
        radius: 6
        color: root.interactive ? Colors.foregroundStrong : Colors.foregroundQuiet
    }
    MouseArea {
        anchors.fill: parent
        enabled: root.interactive
        cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
        onPressed: mouse => { root.dragging = true; root.updateAt(mouse.x) }
        onPositionChanged: mouse => { if (pressed) root.updateAt(mouse.x) }
        onReleased: mouse => { root.updateAt(mouse.x); root.dragging = false }
        onCanceled: root.dragging = false
    }
}
