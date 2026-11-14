import QtQuick

// What the bar injects into every widget slot, and nothing else: identity, plus
// the widget's own shell.json settings.
//
// Deliberately no `bar` host object, unlike a full host facade: this shell has no
// drag/drop, tray or popup coordination to expose, so widgets read Constants and
// Colors directly instead of going through a proxy. Presentation lives in the
// subclasses (IconWidget and friends); this base exists so the host has one
// contract for every widget, whatever it draws.
Item {
  id: root

  // Canonical id: what config/shell.json names and what the bar matches against.
  property string widgetId: ""

  // This widget's extra values from its shell.json entry, e.g.
  // {"id": "clock", "format": 3}. Empty when the entry is a bare id string.
  property var settings: ({})

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return (value === undefined || value === null) ? fallback : value
  }
}
