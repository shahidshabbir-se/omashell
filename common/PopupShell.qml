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
  // Input region while open: everything except the bar strip. The bar stays
  // clickable so another icon can take this panel over, and the bar itself closes
  // it when the click misses an icon.
  mask: Region { item: root.opened ? blocker : null }

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: root.layerNamespace
  // Interactive panels ask for the keyboard while they are open; the read-only
  // ones (clock, weather, world clock) keep taking no keys at all.
  WlrLayershell.keyboardFocus: root.keyboard && root.opened
    ? WlrKeyboardFocus.OnDemand
    : WlrKeyboardFocus.None

  property string layerNamespace: "omashell-popup"
  property bool opened: false
  property bool keyboard: false
  // A PanelNav (or anything with takeFocus()); focused on open when keyboard.
  property var focusTarget: null
  property real anchorX: -1
  property int cardWidth: 340
  property int spacing: 14
  property bool reduceMotion: false

  readonly property var easeOut: [0.23, 1.0, 0.32, 1.0, 1.0, 1.0]
  readonly property real resolvedAnchorX: anchorX >= 0 ? anchorX : width - 100

  // `data`, not `children`: a panel may declare non-visual children (animations,
  // timers) at its root, and only `data` accepts those.
  default property alias content: contentColumn.data

  function duration(ms) {
    return reduceMotion ? 0 : ms
  }

  function open() {
    opened = true
    if (keyboard && focusTarget && focusTarget.takeFocus)
      Qt.callLater(function() { if (root.opened) root.focusTarget.takeFocus() })
  }

  function close() { opened = false }

  function toggle() {
    if (opened) close()
    else open()
  }

  Item {
    id: blocker

    anchors.top: parent.top
    anchors.topMargin: Constants.barHeight
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
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
