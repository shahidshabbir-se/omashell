import QtQuick
import Quickshell
import qs.modules.bar.widgets.indicators

// Runtime reproduction for a stop/start race in StayAwakeService. The fake
// systemd-inhibit in run-stay-awake-lifecycle.sh delays its SIGTERM exit, so
// the old inhibitor is still running when the cell is enabled again. The
// service's active flag must stay true in that state; currently the old
// process's onExited overwrites it.
ShellRoot {
  id: harness
  property int tick: 0
  property bool sawOldExit: false

  function fail(message) {
    console.log("TEST FAIL: " + message)
    Qt.exit(1)
  }

  function pass(message) {
    console.log("TEST PASS: " + message)
    Qt.exit(0)
  }

  Timer {
    interval: 20
    repeat: true
    running: true
    onTriggered: {
      harness.tick++
      // Give the state probe and the first process time to settle.
      if (harness.tick === 15) StayAwakeService.setStayAwake(true, true)
      else if (harness.tick === 35) StayAwakeService.setStayAwake(false, true)
      else if (harness.tick === 36) StayAwakeService.setStayAwake(true, true)
      else if (harness.tick === 80) {
        var state = JSON.stringify({
          active: StayAwakeService.active,
          running: StayAwakeService.inhibitor.running,
          stopping: StayAwakeService.stopping,
          loaded: StayAwakeService.stateLoaded,
          supported: StayAwakeService.supported
        })
        console.log("STAY AWAKE STATE: " + state)
        // After the old process has exited, the re-enabled state has to be
        // reflected by active=true and inhibitor.running=true.
        if (StayAwakeService.active !== true)
          harness.fail("re-enable during stop lost active state")
        else if (StayAwakeService.inhibitor.running !== true)
          harness.fail("re-enable during stop has no live inhibitor")
        else
          harness.pass("re-enable during stop keeps one live inhibitor")
      }
    }
  }
}
