pragma Singleton

import QtQuick

// The only file that knows every bar widget. shell.json stores plain string ids
// (no file paths, no per-widget code), so id -> component resolution has to be
// explicit here: "worldclock" -> WorldClock.qml cannot be derived by convention.
//
// Adding a widget: create modules/bar/widgets/<name>/<Name>.qml, add one entry
// below, then reference its id from config/shell.json.
QtObject {
  id: root

  readonly property var widgets: ({
    workspaces: Qt.resolvedUrl("widgets/workspaces/Workspaces.qml"),
    clock: Qt.resolvedUrl("widgets/clock/Clock.qml"),
    weather: Qt.resolvedUrl("widgets/weather/Weather.qml"),
    worldclock: Qt.resolvedUrl("widgets/worldclock/WorldClock.qml")
  })

  // Unknown id => empty url => the Loader stays empty. A typo in shell.json
  // silently drops the widget instead of breaking the bar.
  function urlFor(id) {
    var url = root.widgets[id]
    return url !== undefined ? url : ""
  }

  function known(id) {
    return root.widgets[id] !== undefined
  }
}
