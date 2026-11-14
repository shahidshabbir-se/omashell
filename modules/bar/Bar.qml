import QtQuick
import Quickshell
import Quickshell.Wayland
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
  }
}
