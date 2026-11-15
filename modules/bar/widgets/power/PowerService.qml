pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "PowerModel.js" as Model

QtObject {
  id: root

  readonly property var device: UPower.displayDevice
  readonly property bool present: !!device && device.isPresent
  readonly property bool discharging: root.present && UPower.onBattery
  readonly property real fraction: present ? Math.max(0, Math.min(1, device.percentage)) : 0
  readonly property bool threshold: present && Model.chargeThresholdActive(
    fraction, discharging, device.state, device.changeRate, device.timeToFull, battery.chargeEnd,
    { Charging: UPowerDeviceState.Charging, Discharging: UPowerDeviceState.Discharging,
      FullyCharged: UPowerDeviceState.FullyCharged, PendingCharge: UPowerDeviceState.PendingCharge })
  readonly property bool full: present && !threshold && !discharging
    && (device.state === UPowerDeviceState.FullyCharged || fraction >= 1)
  readonly property bool charging: present && !discharging && !threshold && !full
  readonly property string mode: !present ? '' : threshold ? 'Threshold' : discharging ? 'On battery' : full ? 'Fully charged' : 'Charging'
  readonly property string icon: present ? Model.batteryIcon(fraction, discharging, full, threshold) : ''
  property var battery: ({})
  property var profiles: []
  property string activeProfile: ''
  property string error: ''
  property bool showPercentage: false
  property bool settingsTouched: false
  property bool savePending: false
  property bool refreshPending: false
  property bool settingsLoaded: false
  property bool sourceKnown: false
  property bool observedOnBattery: false
  property var preferredProfiles: ({})
  property string actionSource: ''
  property string actionProfile: ''
  property bool actionRemember: false
  readonly property string script: String(Qt.resolvedUrl('battery.py')).replace('file://', '')

  function refresh() {
    if (!present) return
    if (statusProc.running) { refreshPending = true; return }
    refreshPending = false
    statusProc.running = true
  }
  function setProfile(profile, remember) {
    if (profiles.indexOf(profile) < 0 || actionProc.running) return
    error = ''
    actionSource = discharging ? 'battery' : 'ac'
    actionProfile = profile
    actionRemember = remember !== false
    actionProc.command = ['powerprofilesctl', 'set', profile]
    actionProc.running = true
  }
  function togglePercentage() {
    settingsTouched = true
    showPercentage = !showPercentage
    savePending = true
    saveSetting()
  }
  function saveSetting() {
    if (!settingsLoaded || !savePending || saveProc.running) return
    savePending = false
    saveProc.command = ['python3', script, 'set', JSON.stringify({ showPercentage: showPercentage, profiles: preferredProfiles })]
    saveProc.running = true
  }
  Component.onCompleted: { settingsProc.running = true; refresh() }
  onPresentChanged: {
    sourceKnown = false
    if (present) { refresh(); sourceInit.restart() }
    else { sourceInit.stop(); restoreTimer.stop() }
  }
  onDischargingChanged: {
    if (present) refresh()
    if (settingsLoaded && present && sourceKnown && observedOnBattery !== discharging) {
      observedOnBattery = discharging
      restoreTimer.restart()
    }
  }
  property Connections deviceChanges: Connections {
    target: root.device
    ignoreUnknownSignals: true
    function onStateChanged() { root.refresh() }
  }
  property Timer sourceInit: Timer {
    interval: 1500
    onTriggered: { root.observedOnBattery = root.discharging; root.sourceKnown = true }
  }
  property Timer restoreTimer: Timer {
    interval: 1000
    onTriggered: {
      if (actionProc.running || statusProc.running) { restart(); return }
      var wanted = root.preferredProfiles[root.discharging ? 'battery' : 'ac']
      if (wanted && wanted !== root.activeProfile) root.setProfile(wanted, false)
    }
  }

  property Process statusProc: Process {
    command: ['python3', root.script, 'status']
    onExited: if (root.refreshPending) Qt.callLater(root.refresh)
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          if (data.battery && Object.keys(data.battery).length) root.battery = data.battery
          if (Array.isArray(data.profiles)) {
            root.profiles = data.profiles
            root.activeProfile = data.activeProfile || ''
          }
        } catch (e) { console.warn('Power status:', e) }
      }
    }
  }
  property Process actionProc: Process {
    stderr: StdioCollector { id: actionError }
    onExited: function(code) {
      if (code !== 0) root.error = actionError.text.trim() || 'Could not change power profile'
      else if (root.actionRemember && ['power-saver', 'balanced', 'performance'].indexOf(root.actionProfile) >= 0) {
        var preferences = Object.assign({}, root.preferredProfiles)
        preferences[root.actionSource] = root.actionProfile
        root.preferredProfiles = preferences
        root.savePending = true
        root.saveSetting()
      }
      root.refresh()
    }
  }
  property Process settingsProc: Process {
    command: ['python3', root.script, 'get']
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          var data = JSON.parse(text)
          if (!root.settingsTouched) root.showPercentage = data.showPercentage === true
          if (data.profiles && typeof data.profiles === 'object') root.preferredProfiles = Object.assign({}, data.profiles, root.preferredProfiles)
        } catch (e) { console.warn('Power settings:', e) }
        root.settingsLoaded = true
        root.saveSetting()
      }
    }
  }
  property Process saveProc: Process {
    onExited: function(code) {
      if (code !== 0) root.error = 'Could not save power settings'
      root.saveSetting()
    }
  }
}
