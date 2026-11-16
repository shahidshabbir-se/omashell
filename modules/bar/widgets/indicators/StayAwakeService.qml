pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

// Stay-awake inhibition for the bar indicator. Unlike the Omarchy idle service,
// this does not own the screensaver or lock; it only holds a portable
// systemd-inhibit blocker. The enabled state is persisted in Omashell's own
// state directory so it survives a shell restart, matching the reference
// indicator's state-file behavior without depending on Omarchy paths.
QtObject {
  id: root

  property bool active: false
  property bool supported: true
  // True from the moment a running inhibitor is asked to stop until its
  // Process reports that it has exited. A re-enable while this is true leaves
  // the request pending; the exit handler starts a fresh inhibitor rather than
  // letting the old process's exit clear the new active state.
  property bool stopping: false
  property bool stateLoaded: false
  property bool hasPendingPersist: false
  property bool pendingPersistValue: false

  readonly property string stateDirectory: Model.stateDirectory(
    Quickshell.env('XDG_STATE_HOME'), Quickshell.env('HOME'))
  readonly property string statePath: Model.statePath(
    Quickshell.env('XDG_STATE_HOME'), Quickshell.env('HOME'))

  function toggle() {
    if (!root.supported) return
    setStayAwake(!root.active, true)
  }

  function setStayAwake(value, persist) {
    var enabled = value === true
    root.stateLoaded = true

    if (root.active === enabled) {
      // Keep the process reconciled with the requested state. This matters
      // when a previous launch failed even though active already matches.
      if (enabled && !root.stopping && !inhibitor.running)
        inhibitor.running = true
      else if (!enabled && inhibitor.running) {
        root.stopping = true
        inhibitor.running = false
      }
      if (persist) writeState(enabled)
      return
    }

    root.active = enabled

    if (enabled) {
      // If an old inhibitor is still stopping, wait for its exit: the exit
      // handler restarts one when active is still true. Starting here would
      // race the old process's onExited callback.
      if (!root.stopping && !inhibitor.running)
        inhibitor.running = true
    } else {
      root.stopping = inhibitor.running
      inhibitor.running = false
    }

    if (persist) writeState(enabled)
  }

  function writeState(enabled) {
    if (stateWriter.running) {
      root.pendingPersistValue = enabled
      root.hasPendingPersist = true
      return
    }
    stateWriter.command = enabled
      ? ["sh", "-c", "mkdir -p \"$1\" && : > \"$1/stay-awake\"", "sh", root.stateDirectory]
      : ["sh", "-c", "rm -f \"$1/stay-awake\"", "sh", root.stateDirectory]
    stateWriter.running = true
  }

  function refreshState() {
    if (!stateProbe.running) stateProbe.running = true
  }

  property Process inhibitor: Process {
    id: inhibitor
    command: ["systemd-inhibit", "--what=idle:sleep", "--who=Omashell", "--why=Stay awake enabled", "--mode=block", "sleep", "infinity"]

    onExited: function(exitCode) {
      if (root.stopping) {
        // This exit belongs to a process the user asked to stop. A re-enable
        // may have arrived while it was winding down, so start a replacement
        // only after the old process is gone.
        root.stopping = false
        if (root.active) inhibitor.running = true
        return
      }

      // An inhibitor that exits while it was wanted is a failed or externally
      // terminated attempt. Do not leave the indicator lit or the state file
      // claiming inhibition.
      if (!root.stateLoaded || exitCode !== 0) root.supported = false
      if (root.active) {
        root.active = false
        if (root.stateLoaded) writeState(false)
      }
    }
  }

  property Process stateProbe: Process {
    id: stateProbe
    command: ["test", "-f", root.statePath]

    onExited: function(exitCode) {
      if (root.stateLoaded) return
      setStayAwake(exitCode === 0, false)
    }
  }

  property Process stateWriter: Process {
    id: stateWriter

    onExited: function(exitCode) {
      if (root.hasPendingPersist) {
        var pending = root.pendingPersistValue
        root.hasPendingPersist = false
        writeState(pending)
      }
    }
  }

  Component.onCompleted: refreshState()
}
