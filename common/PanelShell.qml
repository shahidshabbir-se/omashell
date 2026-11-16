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
                                                                               
                                                                   
                                                                                
                                                                                
  WlrLayershell.keyboardFocus: root.keyboard && root.opened
    ? (root.focusPrimed ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.Exclusive)
    : WlrKeyboardFocus.None

  property string layerNamespace: "omashell-panel"
  property bool opened: false
  property bool keyboard: false
                                                                              
  property var focusTarget: null
  property real anchorX: -1
  property real anchorY: -1
  property int cardWidth: 340
  property int spacing: 14
  property bool reduceMotion: false
  property bool focusPrimed: false

  Timer {
    id: focusPrime
    interval: 75
    onTriggered: if (root.opened) root.focusPrimed = true
  }

  readonly property var easeOut: [0.23, 1.0, 0.32, 1.0, 1.0, 1.0]
  readonly property string barPosition: Config.bar.position
  readonly property bool verticalBar: barPosition === "left" || barPosition === "right"
  // A caller may set anchorY for a vertical bar, but the bar currently hands
  // its along-bar coordinate over in anchorX, as it does for a horizontal one.
  readonly property real anchorAlongBar: root.anchorAlongFor(root.barPosition, anchorX, anchorY, width, height)
  readonly property real cardContentHeight: contentColumn.implicitHeight + Constants.panelPadding * 2 + 4
  // Width is fitted without reading the content, so the card's width and the
  // column's wrapped height cannot feed each other in a binding loop.
  readonly property real resolvedCardWidth: root.fitCardWidth(cardWidth, width, verticalBar,
    Constants.barHeight, Constants.gap)
  readonly property real resolvedCardHeight: root.fitCardHeight(cardContentHeight, height, verticalBar,
    Constants.barHeight, Constants.gap)
  readonly property var cardPlacement: root.cardPosition(anchorAlongBar, width, height, barPosition,
    Constants.barHeight, Constants.gap, resolvedCardWidth, resolvedCardHeight)

                                                                                 
                                                        
  default property alias content: contentColumn.data

  function duration(ms) {
    return reduceMotion ? 0 : ms
  }

  function anchorAlongFor(position, x, y, windowWidth, windowHeight) {
    if (position === "left" || position === "right")
      return y >= 0 ? y : (x >= 0 ? x : windowHeight / 2)
    return x >= 0 ? x : windowWidth - 100
  }

  function clamp(value, minimum, maximum) {
    return maximum < minimum ? minimum : Math.max(minimum, Math.min(value, maximum))
  }

  // A long card is fitted to the desktop area beside the bar, so neither it
  // nor a panel's content can run off an edge. Vertical bars only reduce the
  // available width; horizontal bars only reduce the available height.
  function fitCardWidth(wantedWidth, windowWidth, vertical, barThickness, gap) {
    var width = Math.max(1, Number(wantedWidth) || 1)
    if (windowWidth <= 0) return width
    var maximum = Math.max(1, windowWidth - (vertical ? barThickness : 0) - gap * 2)
    return Math.round(Math.min(width, maximum))
  }

  function fitCardHeight(wantedHeight, windowHeight, vertical, barThickness, gap) {
    var height = Math.max(1, Number(wantedHeight) || 1)
    if (windowHeight <= 0) return height
    var maximum = Math.max(1, windowHeight - (vertical ? 0 : barThickness) - gap * 2)
    return Math.round(Math.min(height, maximum))
  }

  // Where the card goes, as { x, y } in the panel window, for any bar edge.
  // It sits beside a vertical bar and below a top or above a bottom one,
  // centered on the widget that opened it and clamped along the bar.
  function cardPosition(anchor, windowWidth, windowHeight, position, barThickness, gap, cardWidth, cardHeight) {
    var vertical = position === "left" || position === "right"
    var width = Math.max(1, Number(cardWidth) || 1)
    var height = Math.max(1, Number(cardHeight) || 1)
    var x
    var y
    if (vertical) {
      x = position === "left" ? barThickness + gap : windowWidth - barThickness - width - gap
      y = clamp(anchor - height / 2, gap, windowHeight - height - gap)
    } else {
      x = clamp(anchor - width / 2, gap, windowWidth - width - gap)
      y = position === "bottom" ? windowHeight - barThickness - height - gap : barThickness + gap
    }
    return { x: Math.round(x), y: Math.round(y) }
  }

  function open() {
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

  function toggle() {
    if (opened) close()
    else open()
  }

  Item {
    id: blocker

    anchors.top: parent.top
    anchors.topMargin: root.barPosition === "top" ? Constants.barHeight : 0
    anchors.left: parent.left
    anchors.leftMargin: root.barPosition === "left" ? Constants.barHeight : 0
    anchors.right: parent.right
    anchors.rightMargin: root.barPosition === "right" ? Constants.barHeight : 0
    anchors.bottom: parent.bottom
    anchors.bottomMargin: root.barPosition === "bottom" ? Constants.barHeight : 0
    visible: root.opened

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }
  }

  Rectangle {
    id: card

    x: root.cardPlacement.x
    y: root.cardPlacement.y
    width: root.resolvedCardWidth
    height: root.resolvedCardHeight
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
    transformOrigin: root.barPosition === "bottom" ? Item.Bottom
      : (root.barPosition === "left" ? Item.Left : (root.barPosition === "right" ? Item.Right : Item.Top))

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
    }

    Column {
      id: contentColumn
      x: Constants.panelPadding + 2
      y: Constants.panelPadding + 2
      width: card.width - (Constants.panelPadding + 2) * 2
      spacing: root.spacing
    }
  }
}
