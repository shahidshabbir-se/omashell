import QtQuick
import Quickshell
import qs.modules.bar.widgets.music

ShellRoot {
  id: root
  property int phase: 0
  MusicPanel {
    id: panel
    onOpenedChanged: {
      if (!opened && root.phase === 1) {
        root.phase = 2
        reopen.start()
      } else if (!opened && root.phase === 3) {
        console.log('TEST PASS: outside click and Escape dismissed music')
        Qt.exit(0)
      }
    }
  }
  Timer {
    interval: 500; running: true
    onTriggered: { root.phase = 1; panel.open(); clickReady.start() }
  }
  Timer {
    id: clickReady; interval: 500
    onTriggered: {
      if (panel.cardPlacement.x <= 10) { console.log('TEST FAIL: test click overlaps panel'); Qt.exit(1); return }
      console.log('TEST READY click')
    }
  }
  Timer {
    id: reopen; interval: 350
    onTriggered: { root.phase = 3; panel.open(); console.log('TEST READY escape') }
  }
  Timer {
    interval: 7000; running: true
    onTriggered: { console.log('TEST FAIL: dismissal phase=' + root.phase + ' opened=' + panel.opened); Qt.exit(1) }
  }
}
