import QtQuick
import QtQml
import qs.config
import qs.modules.bar

// One bar section (left / center / right). Widgets are loaded from ids, never
// instantiated by name, so the section has no per-widget knowledge.
Row {
  id: root

  // No gap between widgets: each slot carries its own padding (see slotWidth), which
  // is how Omarchy spaces the bar. Row spacing adds to that and is therefore 0.
  spacing: 0

  // Fixed bar height. A Row top-aligns its children, and widgets have different
  // heights (Clock is 12pt text, Weather and WorldClock are 21px icons), so each
  // widget gets a slot of this height and is centred inside it instead.
  height: Constants.barHeight

  // Ids from Config.bar.<section>. Repeater re-creates on change (hot reload).
  property var ids: []

  // Handed to widgets that declare a screen property (Workspaces resolves the
  // monitor-specific workspace block through it).
  property var screen: null

  // Id of the widget whose popup is open; empty when none is. Drives the
  // open-panel mark below, so widgets need no open/closed state of their own.
  property string activeId: ""

  // centerX is local to this section; the bar maps it onto the panel.
  signal activated(string id, real centerX)

  // Hover text for the bar's tooltip; empty when nothing is hovered.
  signal tooltipRequested(string text, real centerX)

  property Item hoverSlot: null

  // Hide at once, show only after the pointer has rested: a tooltip that appears
  // on the way past is noise.
  Timer {
    id: hoverTimer
    interval: Constants.tooltipDelay
    onTriggered: {
      var slot = root.hoverSlot
      if (!slot || slot.tooltipText === "") return
      root.tooltipRequested(slot.tooltipText, slot.x + slot.width / 2)
    }
  }

  function setHovered(slot) {
    root.hoverSlot = slot
    hoverTimer.stop()
    if (!slot || slot.tooltipText === "") {
      root.tooltipRequested("", 0)
      return
    }
    hoverTimer.restart()
  }

  Repeater {
    model: root.ids

    delegate: Item {
      id: slot

      readonly property string widgetId: modelData

      // Same width as the widget, full bar height. The Loader anchors to this
      // slot rather than to the Row: anchoring a child of a positioner is
      // undefined behaviour, anchoring to a plain Item is not.
      readonly property real contentWidth: loader.implicitWidth
      // A widget's footprint includes its own horizontal padding, so the air around
      // it belongs to it rather than to the list. Icon widgets ask for a wider slot
      // (Constants.iconSlot) and composite widgets can opt out by declaring their
      // own barSlotWidth.
      readonly property real slotWidth: loader.item && loader.item.barSlotWidth !== undefined
        ? loader.item.barSlotWidth
        : slot.contentWidth + Constants.barWidgetPadding * 2

      width: slotWidth
      height: root.height
      // An unknown id yields an empty source: status Null, so it takes no space.
      visible: loader.status === Loader.Ready

      // Where this widget's open-panel mark belongs. A widget may name an item to
      // track (an icon, rather than the slot around it) or just how wide the mark
      // is; without a hint the mark underlines the content, never the padding.
      // Same hint names Omarchy uses.
      // Hover text the bar draws in its own tooltip surface.
      readonly property string tooltipText: loader.item && loader.item.tooltip !== undefined
        ? String(loader.item.tooltip)
        : ""

      readonly property Item markItem: loader.item && loader.item.openPanelIndicatorItem !== undefined
        ? loader.item.openPanelIndicatorItem
        : null
      readonly property real markWidth: markItem
        ? markItem.width
        : (loader.item && loader.item.openPanelIndicatorWidth !== undefined
            ? loader.item.openPanelIndicatorWidth
            : slot.contentWidth)
      readonly property real markCenterX: markItem
        ? markItem.mapToItem(slot, markItem.width / 2, 0).x
        : slot.width / 2

      Loader {
        id: loader

        source: WidgetRegistry.urlFor(slot.widgetId)
        anchors.centerIn: parent

        Binding {
          target: loader.item
          property: "screen"
          value: root.screen
          when: loader.item !== null && loader.item.screen !== undefined
          restoreMode: Binding.RestoreNone
        }

        // Identity and settings, the two things the Widget base declares. Injected
        // like `screen`, so a widget that does not declare them is untouched.
        Binding {
          target: loader.item
          property: "widgetId"
          value: slot.widgetId
          when: loader.item !== null && loader.item.widgetId !== undefined
          restoreMode: Binding.RestoreNone
        }

        Binding {
          target: loader.item
          property: "settings"
          value: Config.widgetSettings[slot.widgetId] !== undefined
            ? Config.widgetSettings[slot.widgetId]
            : ({})
          when: loader.item !== null && loader.item.settings !== undefined
          restoreMode: Binding.RestoreNone
        }

        // Bar widgets signal activation under their own names, so all three
        // spellings are accepted. ignoreUnknownSignals keeps silent widgets quiet.
        Connections {
          target: loader.item
          ignoreUnknownSignals: true

          function onActivated() {
            root.activated(slot.widgetId, slot.x + loader.x + loader.width / 2)
          }

          function onCalendarToggleRequested() {
            root.activated(slot.widgetId, slot.x + loader.x + loader.width / 2)
          }

          function onToggleRequested() {
            root.activated(slot.widgetId, slot.x + loader.x + loader.width / 2)
          }
        }
      }

      HoverHandler {
        onHoveredChanged: {
          if (hovered) root.setHovered(slot)
          else if (root.hoverSlot === slot) root.setHovered(null)
        }
      }

      // Open-panel mark: a 2px accent pill on the edge facing the desktop, shown
      // while this widget's popup is open. Text gets the full slot width; an icon
      // reports its ink width, so the mark never looks wider than what it points
      // at. One mark for every widget, so no widget carries hover or active
      // styling of its own.
      Rectangle {
        id: indicator

        visible: opacity > 0
        opacity: root.activeId === slot.widgetId ? 0.9 : 0
        color: Colors.accent
        radius: Math.min(width, height) / 2
        width: slot.markWidth
        height: Constants.indicatorThickness
        x: Math.floor(slot.markCenterX - width / 2)
        y: slot.height - height - Constants.indicatorInset
        z: 10

        Behavior on opacity {
          NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
          }
        }
      }
    }
  }
}
