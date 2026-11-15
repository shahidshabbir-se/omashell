import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.modules.bar.widgets.power

ShellRoot {
  property var service: PowerService
  PowerPanel { id: panel }
  Timer {
    interval: 2500
    running: true
    onTriggered: {
      if (!PowerService.present) {
        console.log('Power service test skipped: no battery')
        Qt.quit()
        return
      }
      if (PowerService.discharging !== UPower.onBattery) {
        console.error('Power source disagrees with UPower')
        Qt.exit(1)
        return
      }
      if (UPower.onBattery && (PowerService.mode !== 'On battery' || panel.phrases.indexOf(panel.status) < 0)) {
        console.error('Battery status does not reflect discharging')
        Qt.exit(1)
        return
      }
      console.log('Power service test passed:', PowerService.mode)
      Qt.quit()
    }
  }
}
