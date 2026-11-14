pragma Singleton

import QtQuick
import Quickshell.Io

// Reads config/shell.json and falls back to the defaults below when the file is
// missing, unreadable, empty or invalid. Nothing outside this file parses JSON.
QtObject {
  id: root

  readonly property var defaults: ({
    version: 1,
    bar: {
      left: ["workspaces"],
      center: ["clock", "weather", "worldclock"],
      right: []
    }
  })

  // null => fall back to defaults. Set only from a successful parse.
  property var raw: null

  readonly property int version: raw && raw.version !== undefined
    ? Number(raw.version)
    : defaults.version

  readonly property var bar: ({
    left: ids(source().left, defaults.bar.left),
    center: ids(source().center, defaults.bar.center),
    right: ids(source().right, defaults.bar.right)
  })

  // Per-widget settings from shell.json, keyed by id. An entry may be a bare id
  // string, or an object {"id": "clock", "format": 3} carrying that widget's own
  // values; the bar injects the object into the widget's `settings`.
  readonly property var widgetSettings: {
    var out = {}
    var src = source()
    var sections = [src.left, src.center, src.right]
    for (var s = 0; s < sections.length; s++) {
      var list = sections[s]
      if (typeof list !== "object" || list === null || typeof list.length !== "number")
        continue
      for (var i = 0; i < list.length; i++) {
        var entry = list[i]
        if (typeof entry !== "object" || entry === null || typeof entry.id !== "string" || entry.id === "")
          continue
        out[entry.id] = entry
      }
    }
    return out
  }

  function source() {
    return (raw && raw.bar) ? raw.bar : defaults.bar
  }

  // Keeps string ids only, drops duplicates and blanks. Unknown ids are kept
  // here on purpose: the widget registry resolves them, and an unknown id
  // loads nothing instead of failing.
  function ids(list, fallback) {
    // Accepts a JSON array from shell.json and a QML list<var> alike, so switching
    // to {"id": ..., "settings": {...}} entries later needs no change here.
    if (typeof list !== "object" || list === null || typeof list.length !== "number")
      return fallback
    var out = []
    for (var i = 0; i < list.length; i++) {
      var raw = list[i]
      // Bare "clock" and {"id": "clock", "format": 3} are both accepted.
      var id = (typeof raw === "object" && raw !== null) ? raw.id : raw
      if (typeof id !== "string" || id === "")
        continue
      if (out.indexOf(id) !== -1)
        continue
      out.push(id)
    }
    return out
  }

  function load(text) {
    try {
      var parsed = JSON.parse(text)
      root.raw = (parsed && typeof parsed === "object") ? parsed : null
    } catch (e) {
      console.warn("omashell: config/shell.json is not valid JSON, using defaults:", e.message)
      root.raw = null
    }
  }

  // QtObject has no default property, so the FileView must be declared as a
  // named property (same idiom as WeatherService's `property Process ...`).
  property FileView configFile: FileView {
    path: String(Qt.resolvedUrl("shell.json")).replace("file://", "")
    watchChanges: true
    printErrors: false

    onFileChanged: reload()
    onLoaded: root.load(text())
    onLoadFailed: root.raw = null
  }
}
