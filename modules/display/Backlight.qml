pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property int value: -1
  property string error: ""
  property int pending: -1
  property int pendingDelta: 0
  readonly property int displayValue: pending >= 0 ? pending : worker.running && worker.writing ? worker.requested : value
  readonly property var helper: ["python3", decodeURIComponent(String(Qt.resolvedUrl("backlight.py")).replace(/^file:\/\//, ""))]

  function read() {
    if (worker.running || pending >= 0) return
    worker.writing = false
    worker.command = helper
    worker.running = true
  }

  function set(percent) {
    pendingDelta = 0
    pending = Math.max(1, Math.min(100, Math.round(percent)))
    flush()
  }

  function adjust(delta) {
    if (pending >= 0) set(pending + delta)
    else if (worker.running && worker.writing) set(worker.requested + delta)
    else if (value >= 0) set(value + delta)
    else {
      pendingDelta += delta
      read()
    }
  }

  function flush() {
    if (worker.running || pending < 0) return
    worker.writing = true
    worker.requested = pending
    worker.command = helper.concat([String(pending)])
    pending = -1
    worker.running = true
  }

  Process {
    id: worker
    property bool writing: false
    property int requested: 0
    stdout: StdioCollector { id: output }
    stderr: StdioCollector {}
    onExited: function(code) {
      var data
      try { data = JSON.parse(output.text) } catch (_) { data = {} }
      if (code === 0 && Number.isInteger(data.value)) {
        root.error = ""
        root.value = data.value
        if (root.pendingDelta) root.set(root.value + root.pendingDelta)
      } else {
        root.pendingDelta = 0
        if (writing) root.error = data.error || "Could not set brightness."
        else root.value = -1
      }
      Qt.callLater(root.flush)
    }
  }
}
