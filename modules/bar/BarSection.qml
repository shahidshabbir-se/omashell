import QtQuick
import QtQml
import qs.config
import qs.modules.bar

// One bar section (left / center / right). Widgets are loaded from ids, never
// instantiated by name, so the section has no per-widget knowledge.
Row {
  id: root

  // Matches the previous hard-coded bar layout (Row spacing 14, margin 10 in Bar).
  spacing: 14

  // Fixed bar height. A Row top-aligns its children, and widgets have different
  // heights (Clock is 12pt text, Weather and WorldClock are 21px icons), so each
  // widget gets a slot of this height and is centred inside it instead.
  height: Constants.barHeight

  // Ids from Config.bar.<section>. Repeater re-creates on change (hot reload).
  property var ids: []

  // Handed to widgets that declare a screen property (Workspaces resolves the
  // monitor-specific workspace block through it).
  property var screen: null

  // centerX is local to this section; the bar maps it onto the panel.
  signal activated(string id, real centerX)

  Repeater {
    model: root.ids

    delegate: Item {
      id: slot

      readonly property string widgetId: modelData

      // Same width as the widget, full bar height. The Loader anchors to this
      // slot rather than to the Row: anchoring a child of a positioner is
      // undefined behaviour, anchoring to a plain Item is not.
      width: loader.implicitWidth
      height: root.height
      // An unknown id yields an empty source: status Null, so it takes no space.
      visible: loader.status === Loader.Ready

      Loader {
        id: loader

        source: WidgetRegistry.urlFor(slot.widgetId)
        anchors.verticalCenter: parent.verticalCenter

        Binding {
          target: loader.item
          property: "screen"
          value: root.screen
          when: loader.item !== null && loader.item.screen !== undefined
          restoreMode: Binding.RestoreNone
        }

        // Bar widgets signal activation under their own names today, so both
        // spellings are accepted. ignoreUnknownSignals keeps silent widgets quiet.
        Connections {
          target: loader.item
          ignoreUnknownSignals: true

          function onCalendarToggleRequested() {
            root.activated(slot.widgetId, slot.x + loader.x + loader.width / 2)
          }

          function onToggleRequested() {
            root.activated(slot.widgetId, slot.x + loader.x + loader.width / 2)
          }
        }
      }
    }
  }
}
