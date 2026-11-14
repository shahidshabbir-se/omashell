import QtQuick
import QtQml
import qs.modules.bar

// One bar section (left / center / right). Widgets are loaded from ids, never
// instantiated by name, so the section has no per-widget knowledge.
Row {
  id: root

  // Matches the previous hard-coded bar layout (Row spacing 14, margin 10 in Bar).
  spacing: 14

  // Ids from Config.bar.<section>. Repeater re-creates on change (hot reload).
  property var ids: []

  // Handed to widgets that declare a screen property (Workspaces resolves the
  // monitor-specific workspace block through it).
  property var screen: null

  // centerX is local to this section; the bar maps it onto the panel.
  signal activated(string id, real centerX)

  Repeater {
    model: root.ids

    delegate: Loader {
      id: loader

      readonly property string widgetId: modelData

      source: WidgetRegistry.urlFor(loader.widgetId)
      // An unknown id yields an empty source: status Null, so it takes no space.
      visible: loader.status === Loader.Ready

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
          root.activated(loader.widgetId, loader.x + loader.width / 2)
        }

        function onToggleRequested() {
          root.activated(loader.widgetId, loader.x + loader.width / 2)
        }
      }
    }
  }
}
