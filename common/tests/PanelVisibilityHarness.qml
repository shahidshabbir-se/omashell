import QtQuick
import Quickshell
import qs.common

ShellRoot {
  PanelShell { id: panel }
  Timer {
    interval: 150
    running: true
    onTriggered: {
      if (panel.visible || panel.opened) { console.log('TEST FAIL: initially mapped'); Qt.exit(1); return }
      panel.open()
      opening.start()
    }
  }
  Timer {
    id: opening
    interval: 350
    onTriggered: {
      if (!panel.visible || !panel.opened) { console.log('TEST FAIL: panel did not open'); Qt.exit(1); return }
      panel.close()
      closing.start()
    }
  }
  Timer {
    id: closing
    interval: 40
    onTriggered: {
      if (!panel.visible || panel.opened) { console.log('TEST FAIL: exit fade unmapped early'); Qt.exit(1); return }
      closed.start()
    }
  }
  Timer {
    id: closed
    interval: 400
    onTriggered: {
      if (panel.visible || panel.opened) { console.log('TEST FAIL: closed panel remains mapped'); Qt.exit(1); return }
      panel.open()
      reopening.start()
    }
  }
  Timer {
    id: reopening
    interval: 300
    onTriggered: {
      if (!panel.visible || !panel.opened) { console.log('TEST FAIL: panel did not reopen'); Qt.exit(1); return }
      console.log('TEST PASS')
      Qt.exit(0)
    }
  }
}
