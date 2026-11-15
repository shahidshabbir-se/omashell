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
  mask: Region { item: root.opened ? scrim : null }

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: root.layerNamespace
  WlrLayershell.keyboardFocus: root.keyboard && root.opened
    ? (root.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
    : WlrKeyboardFocus.None

  property string layerNamespace: "omashell-overlay"
  property bool opened: false
  property bool keyboard: true
  property var focusTarget: null
  property bool cardChrome: true
  property int cardWidth: 360
  property int padding: 18
  property int spacing: 14
  property bool reduceMotion: false
  property bool focusPrimed: false

  default property alias content: contentColumn.data

  readonly property var easeOut: [0.23, 1.0, 0.32, 1.0, 1.0, 1.0]

  signal dismissed()

  function duration(ms) {
    return reduceMotion ? 0 : ms
  }

                                                                             
                                                
  function present() {
    opened = true
    focusPrimed = false
    focusPrime.restart()
    if (keyboard && focusTarget && focusTarget.takeFocus)
      Qt.callLater(function() { if (root.opened) root.focusTarget.takeFocus() })
  }

  function close() {
    focusPrime.stop()
    focusPrimed = false
    opened = false
  }

  Timer {
    id: focusPrime
    interval: 75
    onTriggered: if (root.opened) root.focusPrimed = true
  }

  Shortcut {
    sequence: "Escape"
    context: Qt.WindowShortcut
    enabled: root.opened
    onActivated: root.dismissed()
  }

  Rectangle {
    id: scrim

    anchors.fill: parent
    visible: opacity > 0
    color: "#000000"
    property real shown: root.opened ? 0.82 : 0

    Behavior on shown {
      NumberAnimation {
        duration: root.duration(root.opened ? 180 : 120)
        easing.type: Easing.Bezier
        easing.bezierCurve: root.easeOut
      }
    }

    opacity: shown

    MouseArea {
      anchors.fill: parent
      onClicked: root.dismissed()
    }
  }

  Rectangle {
    id: card

    anchors.centerIn: parent
    width: root.cardWidth
    height: contentColumn.implicitHeight + root.padding * 2 + 4
    visible: root.opened || opacity > 0
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

    color: root.cardChrome ? Colors.background : "transparent"
    radius: Constants.cornerRadius
    border.width: root.cardChrome ? 2 : 0
    border.color: Colors.accent
    opacity: shown
    scale: 0.97 + 0.03 * shown

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
    }

    Column {
      id: contentColumn

      x: root.padding
      y: root.padding
      width: card.width - root.padding * 2
      spacing: root.spacing
    }
  }
}
