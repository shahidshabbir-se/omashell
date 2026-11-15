
import QtQuick
import Quickshell.Io
import qs.config

                                                                      
                                                                          
                         
  
                                                                          
                                                                            
                                                                          
                                                                           
                                                          
Item {
  id: root


  property bool opened: false
  property string connectionName: ""

  property bool running: false
  property bool expectedStop: false
  property bool pendingRun: false
  property string phase: ""                             
  property string stderrText: ""
  property string downloadMbps: ""
  property string uploadMbps: ""
  property string error: ""

  readonly property real downloadValue: toMbps(downloadMbps)
  readonly property real uploadValue: toMbps(uploadMbps)

  function toMbps(raw) {
    var value = parseFloat(raw)
    return isFinite(value) && value > 0 ? value : 0
  }

  function open(payloadJson) {
    var payload = {}
    try { payload = JSON.parse(payloadJson || "{}") || {} } catch (e) {}
    if (payload.connection !== undefined) root.connectionName = String(payload.connection)
    else refreshConnectionName()
    root.opened = true
    runSpeedTest()
  }

  function close() {
    root.opened = false
    root.pendingRun = false
    phaseTimer.stop()
                                                                           
                                               
    root.phase = ""
    root.running = false
    if (speedTestProc.running) {
      root.expectedStop = true
      speedTestProc.running = false
    }
  }

  function dismiss() { close() }

  function refreshConnectionName() {
    root.connectionName = ""
    statusProc.running = false
    statusProc.running = true
  }

  function updateSpeedTestLine(line) {
    var value = parseFloat(line)
    if (!isFinite(value) || value < 0) return

    if (phase === "down") downloadMbps = String(value)
    else if (phase === "up") uploadMbps = String(value)
  }

  function runSpeedTest() {
    if (speedTestProc.running) {
                                                                             
                                                                    
      if (expectedStop) pendingRun = true
      return
    }
    error = ""
    downloadMbps = ""
    uploadMbps = ""
    running = true
    startPhase("down")
  }

  function startPhase(nextPhase) {
    expectedStop = false
    phase = nextPhase
    stderrText = ""
    speedTestProc.command = ["python3", String(Qt.resolvedUrl("scripts/speedtest.py")).replace("file://", ""), nextPhase]
    speedTestProc.running = true
    phaseTimer.restart()
  }

  function stopPhase() {
    phaseTimer.stop()
    error = "Speed test failed"
    phase = ""
    running = false
    if (speedTestProc.running) {
      expectedStop = true
      speedTestProc.running = false
      return
    }
    finishPhase()
  }

  function finishPhase() {
    if (phase === "down") {
      startPhase("up")
      return
    }

    phase = ""
    running = false
    expectedStop = false
  }

  Process {
    id: speedTestProc
    stdout: SplitParser { onRead: function(line) { root.updateSpeedTestLine(line) } }
                                                                            
                                                                            
                                      
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        root.stderrText = String(text || "").trim()
        if (root.error !== "" && root.stderrText !== "") root.error = root.stderrText
      }
    }
    onExited: function(exitCode) {
      phaseTimer.stop()

      if (root.pendingRun) {
        root.pendingRun = false
        root.expectedStop = false
        if (root.opened) Qt.callLater(root.runSpeedTest)
        return
      }

      if (!root.expectedStop && exitCode !== 0) {
        root.error = root.stderrText || "Speed test failed"
        root.phase = ""
        root.running = false
        return
      }

      root.expectedStop = false
      root.finishPhase()
    }
  }

  Timer {
    id: phaseTimer
                                                                      
                                                                   
    interval: 20000
    repeat: false
    onTriggered: root.stopPhase()
  }

                                                                        
                                                                    
  Process {
    id: statusProc
    command: ["bash", String(Qt.resolvedUrl("scripts/network-status.sh")).replace("file://", "")]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var fields = String(text || "").trim().split("\t")
        if (fields[0] === "wifi") root.connectionName = fields[1] || "Wi-Fi"
        else if (fields[0] === "ethernet") root.connectionName = "Ethernet"
      }
    }
  }

  SpeedTestOverlay {
    fontFamily: Constants.fontFamily
    layerNamespace: "omashell-network-speedtest"
    title: root.connectionName
    leftLabel: "DOWNLOAD"
    rightLabel: "UPLOAD"
    runAgainTooltip: "Measure again via Cloudflare"
    running: root.running
    leftValue: root.downloadValue
    rightValue: root.uploadValue
    leftLive: root.running && root.phase === "down"
    rightLive: root.running && root.phase === "up"
    error: root.error
    open: root.opened
    onCloseRequested: root.dismiss()
    onRunAgainRequested: root.runSpeedTest()
  }
}
