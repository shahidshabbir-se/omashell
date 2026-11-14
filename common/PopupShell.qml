import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

PanelWindow {
  id: root

  anchors.top: true
  anchors.right: true
  anchors.bottom: true
  anchors.left: true
  color: "transparent"
  exclusionMode: ExclusionMode.Ignore
  mask: Region { item: root.opened ? blocker : null }

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: root.layerNamespace
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

  property string layerNamespace: "omashell-popup"
  property bool opened: false
  property real anchorX: -1
  property int cardWidth: 340
  property int spacing: 14
  property bool reduceMotion: false

  readonly property var easeOut: [0.23, 1.0, 0.32, 1.0, 1.0, 1.0]
  readonly property real resolvedAnchorX: anchorX >= 0 ? anchorX : width - 100

  default property alias content: contentColumn.children

  function duration(ms) {
    return reduceMotion ? 0 : ms
  }

  function open() { opened = true }
  function close() { opened = false }

  function toggle() {
    if (opened) close()
    else open()
  }

  Item {
    id: blocker
    anchors.fill: parent
    visible: root.opened

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }
  }

  Rectangle {
    id: card

    x: Math.max(Constants.gap, Math.min(root.resolvedAnchorX - width / 2, root.width - width - Constants.gap))
    y: Constants.barHeight + Constants.gap
    width: root.cardWidth
    height: contentColumn.implicitHeight + Constants.popupPadding * 2 + 4
    visible: root.opened || opacity > 0
    clip: true
    property real shown: root.opened ? 1 : 0

    Behavior on shown {
      NumberAnimation {
        duration: root.duration(root.opened ? 180 : 120)
        easing.type: Easing.Bezier
        easing.bezierCurve: root.easeOut
      }
    }

    Behavior on height {
      NumberAnimation {
        duration: root.duration(200)
        easing.type: Easing.Bezier
        easing.bezierCurve: root.easeOut
      }
    }

    color: Colors.background
    radius: Constants.cornerRadius
    border.width: 2
    border.color: Colors.accent
    opacity: shown
    scale: 0.97 + 0.03 * shown
    transformOrigin: Item.Top

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
    }

    Column {
      id: contentColumn
      x: Constants.popupPadding + 2
      y: Constants.popupPadding + 2
      width: card.width - (Constants.popupPadding + 2) * 2
      spacing: root.spacing
    }
  }
}
