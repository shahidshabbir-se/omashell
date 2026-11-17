import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.modules.bar.widgets.audio
import 'VolumeModel.js' as Model

Scope {
  id: root
  property var observed: null
  property var popupScreen: null
  property bool opened: false
  property var display: Model.state(0, false)

  function focusedScreen() {
    var monitor = Hyprland.focusedMonitor
    var name = monitor ? String(monitor.name || '') : ''
    for (var i = 0; i < Quickshell.screens.length; i++)
      if (Quickshell.screens[i].name === name) return Quickshell.screens[i]
    return Quickshell.screens.length ? Quickshell.screens[0] : null
  }

  function observe() {
    var sink = AudioService.hasOutput ? AudioService.sink : null
    var previousSink = observed ? observed.sink : null
    observed = Model.observe(observed, sink, AudioService.outputVolume, AudioService.outputMuted)
    if (sink !== previousSink) {
      opened = false
      hideTimer.stop()
    }
    if (!observed.changed) return
    display = Model.state(observed.volume, observed.muted)
    if (!opened) popupScreen = focusedScreen()
    opened = popupScreen !== null
    if (opened) hideTimer.restart()
  }

  function scheduleObserve() { Qt.callLater(root.observe) }
  Component.onCompleted: scheduleObserve()
  Connections {
    target: AudioService
    function onSinkChanged() { root.scheduleObserve() }
    function onHasOutputChanged() { root.scheduleObserve() }
    function onOutputVolumeChanged() { root.scheduleObserve() }
    function onOutputMutedChanged() { root.scheduleObserve() }
  }
  Connections {
    target: Quickshell
    function onScreensChanged() {
      if (root.opened && Quickshell.screens.indexOf(root.popupScreen) < 0) {
        root.popupScreen = root.focusedScreen()
        if (!root.popupScreen) root.opened = false
      }
    }
  }
  Timer { id: hideTimer; interval: 1200; onTriggered: root.opened = false }
  VolumeFlyer {
    output: root.popupScreen
    opened: root.opened
    display: root.display
  }
}
