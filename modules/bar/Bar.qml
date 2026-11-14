import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.config
import qs.modules.bar

PanelWindow {
  id: root

  anchors.top: true
  anchors.left: true
  anchors.right: true
  implicitHeight: Constants.barHeight
  color: Colors.background

  // Distance from the screen edge to the first widget, same token the sections use.
  readonly property int sectionMargin: Constants.barSectionMargin

  // Which widget's popup is open, resolved by the shell from its popup map.
  property string activeId: ""

  // Emitted for any widget that signals activation. The shell resolves the id
  // to a popup; the bar has no idea popups exist.
  signal widgetActivated(string id, real anchorX)

  // Hover text and where to put it, in content coordinates.
  property string tooltipText: ""
  property real tooltipX: 0

  // Set by the shell while any popup is open. A tooltip over an open panel is
  // noise - the pointer is usually passing the bar on its way into the panel.
  property bool panelOpen: false

  onPanelOpenChanged: if (root.panelOpen) root.tooltipText = ""

  // A click on the bar that misses every icon: the shell closes the open popup.
  signal barClicked()

  function showTooltip(text, centerX, section) {
    if (text === "") {
      root.tooltipText = ""
      return
    }
    root.tooltipX = root.contentItem.mapFromItem(section, centerX, 0).x
    root.tooltipText = text
  }

  // Hover tooltip. A PopupWindow relative to the bar window rather than an
  // independent layer surface: it shares the bar's output, so it cannot adopt a
  // different scale, and relativeX/relativeY are integers by type.
  PopupWindow {
    id: tooltipWindow

    // 0.3.2 deprecated parentWindow/relativeX/relativeY for the anchor object.
    anchor.window: root
    anchor.rect.x: Math.round(root.tooltipX - width / 2)
    anchor.rect.y: Constants.barHeight + Constants.gap
    anchor.rect.width: 1
    anchor.rect.height: 1

    visible: root.tooltipText !== "" && !root.panelOpen
    color: "transparent"
    // Sized from the label, not the bubble: a plain Rectangle has no implicit
    // size from its children, and a zero-width popup is a Wayland protocol error.
    implicitWidth: Math.ceil(tooltipLabel.implicitWidth) + 20
    implicitHeight: Math.max(22, Math.ceil(tooltipLabel.implicitHeight) + 14)

    // Reveal one frame after the surface maps. The first configure can arrive at a
    // different scale than the bar (measured: popup dpr 2, bar 1.3333), which would
    // draw the 1px border at two widths. Waiting a frame lets Qt settle it - and a
    // strict devicePixelRatio equality against the bar never passes here, so that
    // gate is deliberately not used.
    property bool revealed: false

    onVisibleChanged: {
      if (!visible) {
        revealed = false
        return
      }
      Qt.callLater(function() { if (tooltipWindow.visible) tooltipWindow.revealed = true })
    }

    Rectangle {
      id: tooltipBubble

      anchors.fill: parent
      opacity: tooltipWindow.revealed ? 1 : 0
      color: Colors.darkBackground
      border.width: 1
      border.color: Colors.muted
      radius: Constants.cornerRadius

      Text {
        id: tooltipLabel

        anchors.centerIn: parent
        text: root.tooltipText
        color: Colors.foreground
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontBody
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
      }
    }
  }

  // Under the sections (declared first), so icons keep their own clicks.
  MouseArea {
    anchors.fill: parent
    onClicked: root.barClicked()
  }

  BarSection {
    id: leftSection

    ids: Config.bar.left
    screen: root.screen
    activeId: root.activeId
    anchors.left: parent.left
    anchors.leftMargin: root.sectionMargin
    anchors.verticalCenter: parent.verticalCenter

    onActivated: function(id, x) {
      root.widgetActivated(id, root.contentItem.mapFromItem(leftSection, x, 0).x)
    }

    onTooltipRequested: function(text, x) { root.showTooltip(text, x, leftSection) }
  }

  BarSection {
    id: centerSection

    ids: Config.bar.center
    screen: root.screen
    activeId: root.activeId
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter

    onActivated: function(id, x) {
      root.widgetActivated(id, root.contentItem.mapFromItem(centerSection, x, 0).x)
    }

    onTooltipRequested: function(text, x) { root.showTooltip(text, x, centerSection) }
  }

  BarSection {
    id: rightSection

    ids: Config.bar.right
    screen: root.screen
    activeId: root.activeId
    anchors.right: parent.right
    anchors.rightMargin: root.sectionMargin
    anchors.verticalCenter: parent.verticalCenter

    onActivated: function(id, x) {
      root.widgetActivated(id, root.contentItem.mapFromItem(rightSection, x, 0).x)
    }

    onTooltipRequested: function(text, x) { root.showTooltip(text, x, rightSection) }
  }
}
