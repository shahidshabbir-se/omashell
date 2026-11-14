import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.common
import qs.config

Item {
  id: root

  property var screen: null

  readonly property int slots: 10

  property var workspaceList: []
  property var activeWorkspace: ({})
  property var monitorList: []
  property string modeFromState: ""
  property string defaultMode: "dwindle"
  property bool statePending: false

  readonly property string screenName: screen ? screen.name : ""

  readonly property var monitor: {
    var name = root.screenName
    if (name === "" && root.activeWorkspace && root.activeWorkspace.monitor)
      name = root.activeWorkspace.monitor

    for (var i = 0; i < root.monitorList.length; i++) {
      if (root.monitorList[i].name === name) return root.monitorList[i]
    }
    return null
  }

  readonly property string monitorName: monitor
    ? monitor.name
    : (screenName !== "" ? screenName : (activeWorkspace && activeWorkspace.monitor ? activeWorkspace.monitor : ""))

  readonly property int activeId: monitor && monitor.activeWorkspace
    ? monitor.activeWorkspace.id
    : (activeWorkspace && activeWorkspace.id ? activeWorkspace.id : -1)

  readonly property string activeMode: modeFromState === "floating"
    ? "floating"
    : (activeWorkspace && activeWorkspace.tiledLayout === "scrolling" ? "scrolling" : "dwindle")

  property var blocks: ({})

  function readBlocks(text) {
    var next = {}
    var lines = String(text || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var fields = lines[i].split("\t")
      if (fields.length >= 3 && fields[1] !== "") next[fields[1]] = parseInt(fields[0], 10)
    }
    root.blocks = next
  }

  readonly property string stateHome: Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")
  readonly property string modeFile: stateHome + "/omarchy/workspace-layouts/" + root.activeId + ".lua"

  FileView {
    path: root.stateHome + "/omarchy/monitors/workspaces"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.readBlocks(text())
    onLoadFailed: root.readBlocks("")
  }

  FileView {
    path: root.modeFile
    watchChanges: true
    printErrors: false
    onFileChanged: root.refreshSoon()
    onLoaded: root.refreshSoon()
    onLoadFailed: root.refreshSoon()
  }

  function blockOf(id) {
    return Math.floor((id - 1) / root.slots)
  }

  function slotOf(id) {
    return (id - 1) % root.slots + 1
  }

  readonly property int block: {
    var block = root.blocks[root.monitorName]
    if (block !== undefined) return block
    return root.activeId > 0 ? root.blockOf(root.activeId) : 0
  }

  function workspaceById(id) {
    for (var i = 0; i < root.workspaceList.length; i++) {
      if (root.workspaceList[i].id === id) return root.workspaceList[i]
    }
    return null
  }

  function workspaceIds() {
    var base = root.block * root.slots
    var ids = [base + 1, base + 2, base + 3, base + 4, base + 5]
    var guests = []

    for (var i = 0; i < root.workspaceList.length; i++) {
      var workspace = root.workspaceList[i]
      var id = workspace.id
      if (id <= 0) continue
      if (root.blockOf(id) === root.block) {
        if (ids.indexOf(id) === -1) ids.push(id)
      } else if (workspace.monitor === root.monitorName) {
        guests.push(id)
      }
    }

    ids.sort(function(left, right) { return left - right })
    guests.sort(function(left, right) { return left - right })
    return ids.concat(guests)
  }

  function modeGlyph(mode) {
    if (mode === "scrolling") return "\uDB81\uDF65"
    if (mode === "floating") return "\uDB81\uDD36"
    return "\uDB85\uDCFB"
  }

  function wrapperScript(tail) {
    return "export PATH=\"/etc/profiles/per-user/$USER/bin:/run/current-system/sw/bin:$PATH\"; "
      + "if command hyprctl -j instances >/dev/null 2>&1; then "
      + "h() { command hyprctl -i 0 \"$@\"; }; else h() { command hyprctl \"$@\"; }; fi; "
      + tail
  }

  property var dispatchQueue: []

  function runHyprctl(args) {
    root.dispatchQueue.push(args)
    if (!dispatchProc.running) root.startNextDispatch()
  }

  function startNextDispatch() {
    if (root.dispatchQueue.length === 0) return
    var args = root.dispatchQueue.shift()
    dispatchProc.command = ["bash", "-c", root.wrapperScript("h \"$@\""), "bash"].concat(args)
    dispatchProc.running = true
  }

  function focusWorkspace(id) {
    root.runHyprctl(["dispatch", "hl.dsp.focus({ workspace = \"" + id + "\" })"])
  }

  property real wheelAccumulator: 0

  function wheelSteps(accumulator, delta) {
    delta = Math.max(-120, Math.min(120, delta))
    if (accumulator * delta < 0) accumulator = 0
    var total = accumulator + delta
    var steps = total < 0 ? Math.ceil(total / 120) : Math.floor(total / 120)
    return { steps: steps, remainder: total - steps * 120 }
  }

  function scrollWorkspaces(delta) {
    var wheel = root.wheelSteps(root.wheelAccumulator, delta)
    root.wheelAccumulator = wheel.remainder
    if (wheel.steps === 0) return

    var ids = root.workspaceIds()
    var index = ids.indexOf(root.activeId)
    if (index === -1) return
    var target = ids[Math.max(0, Math.min(ids.length - 1, index - wheel.steps))]
    if (target !== ids[index]) root.focusWorkspace(target)
  }

  function nextMode() {
    if (root.activeMode === "dwindle") return "scrolling"
    return "dwindle"
  }

  property string pendingLayoutMode: ""

  function cycleLayout() {
    if (root.activeId < 1) return

    var mode = root.nextMode()
    root.pendingLayoutMode = mode
    var apply = "hl.workspace_rule({ workspace = \"" + root.activeId + "\", layout = \"" + mode + "\" })"
    layoutApplyProc.command = ["bash", "-c", root.wrapperScript("h \"$@\""), "bash", "eval", apply]
    layoutApplyProc.running = true
  }

  function refreshSoon() {
    stateDebounce.restart()
  }

  function refreshState() {
    if (stateProc.running) {
      root.statePending = true
      return
    }

    var script = root.wrapperScript(
      "printf '__WORKSPACES__\\n'; h -j workspaces; "
        + "printf '\\n__ACTIVE__\\n'; h -j activeworkspace; "
        + "printf '\\n__MONITORS__\\n'; h -j monitors; "
        + "id=$(h -j activeworkspace | jq -r '.id // empty'); "
        + "mode=\"\"; "
        + "if [ -n \"$id\" ]; then "
        + "modes=\"${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/workspace-layouts\"; "
        + "mode=$(sed -n 's/.*mode = \"\\([a-z]*\\)\".*/\\1/p' \"$modes/$id.lua\" 2>/dev/null); "
        + "if [ -z \"$mode\" ] && [ -f \"$modes/default.lua\" ]; then "
        + "mode=$(sed -n 's/.*default = \"\\([a-z]*\\)\".*/\\1/p' \"$modes/default.lua\"); "
        + "fi; fi; "
        + "printf '\\n__MODE__\\n%s\\n' \"$mode\"; "
        + "default=\"\"; "
        + "modes=\"${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/workspace-layouts\"; "
        + "default=$(sed -n 's/.*default = \"\\([a-z]*\\)\".*/\\1/p' \"$modes/default.lua\" 2>/dev/null); "
        + "if [ -z \"$default\" ]; then default=$(h getoption general:layout -j | jq -r '.str // \"dwindle\"'); fi; "
        + "printf '__DEFAULT__\\n%s\\n' \"$default\"")

    stateProc.command = ["bash", "-c", script]
    stateProc.running = true
  }

  function readState(raw) {
    var wsMarker = "__WORKSPACES__"
    var activeMarker = "__ACTIVE__"
    var monitorMarker = "__MONITORS__"
    var modeMarker = "__MODE__"
    var defaultMarker = "__DEFAULT__"

    var wsAt = raw.indexOf(wsMarker)
    var activeAt = raw.indexOf(activeMarker)
    var monitorAt = raw.indexOf(monitorMarker)
    var modeAt = raw.indexOf(modeMarker)
    var defaultAt = raw.indexOf(defaultMarker)
    if (wsAt < 0 || activeAt < 0 || monitorAt < 0 || modeAt < 0 || defaultAt < 0) return

    try {
      root.workspaceList = JSON.parse(raw.substring(wsAt + wsMarker.length, activeAt).trim())
      root.activeWorkspace = JSON.parse(raw.substring(activeAt + activeMarker.length, monitorAt).trim())
      root.monitorList = JSON.parse(raw.substring(monitorAt + monitorMarker.length, modeAt).trim())
      root.modeFromState = raw.substring(modeAt + modeMarker.length, defaultAt).trim()
      root.defaultMode = raw.substring(defaultAt + defaultMarker.length).trim() || "dwindle"
    } catch (e) {
    }
  }

  property Process stateProc: Process {
    id: stateProc

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.readState(String(text || ""))
    }

    onExited: {
      if (!root.statePending) return
      root.statePending = false
      Qt.callLater(root.refreshState)
    }
  }

  property Process dispatchProc: Process {
    id: dispatchProc

    onExited: function(exitCode) {
      if (exitCode !== 0) console.warn("omashell workspaces: dispatch failed with exit", exitCode)
      root.startNextDispatch()
      root.refreshSoon()
    }
  }

  property Process layoutApplyProc: Process {
    id: layoutApplyProc

    onExited: function(exitCode) {
      if (exitCode !== 0) {
        console.warn("omashell workspaces: layout apply failed with exit", exitCode)
        root.toggleRefreshTimer.restart()
        return
      }

      modeWriteProc.command = ["bash", "-c", root.wrapperScript(
        "modes=\"${XDG_STATE_HOME:-$HOME/.local/state}/omarchy/workspace-layouts\"; "
          + "mkdir -p \"$modes\"; "
          + "if [ \"$2\" = \"$3\" ]; then rm -f \"$modes/$1.lua\"; "
          + "else printf 'o.workspace_mode({ workspace = \"%s\", mode = \"%s\" })\\n' \"$1\" \"$2\" > \"$modes/$1.lua\"; fi"),
        "bash", String(root.activeId), root.pendingLayoutMode, root.defaultMode]
      modeWriteProc.running = true
      root.toggleRefreshTimer.restart()
    }
  }

  property Process modeWriteProc: Process {
    id: modeWriteProc
  }

  property Timer stateDebounce: Timer {
    interval: 80
    onTriggered: root.refreshState()
  }

  property Timer toggleRefreshTimer: Timer {
    interval: 300
    onTriggered: root.refreshState()
  }

  IpcHandler {
    target: "omashell.workspaces"

    function focus(workspaceId: string): void { root.focusWorkspace(parseInt(workspaceId, 10)) }
    function refresh(): void { root.refreshState() }
  }

  Component.onCompleted: root.refreshState()
  onScreenChanged: root.refreshSoon()

  Connections {
    target: Hyprland
    function onRawEvent(event) { root.refreshSoon() }
  }

  // Its grid spaces its own buttons, so padding around it would only read as a gap
  // before the next widget. Omarchy's workspaces widget is padded the same way: not.
  readonly property real barSlotWidth: root.implicitWidth

  implicitWidth: grid.implicitWidth + 1.5
  implicitHeight: grid.implicitHeight

  GridLayout {
    id: grid
    anchors.fill: parent
    anchors.rightMargin: 1.5
    columns: root.workspaceIds().length
    columnSpacing: 1
    rowSpacing: 0

    Repeater {
      model: root.workspaceIds()

      Item {
        id: workspaceButton

        required property int modelData
        required property int index

        readonly property var workspace: root.workspaceById(modelData)
        readonly property bool occupied: workspace !== null && workspace.windows > 0
        readonly property bool shown: root.activeId === modelData
        readonly property int slot: root.slotOf(modelData)
        readonly property bool firstGuest: root.blockOf(modelData) !== root.block
          && index > 0
          && root.blockOf(root.workspaceIds()[index - 1]) === root.block

        Layout.leftMargin: firstGuest ? 6 : 0
        width: 20
        height: Constants.barHeight
        opacity: occupied || shown ? 1 : 0.5

        // A digit is text, so it goes through the figure-centred label. The active
        // workspace shows a layout glyph instead, and a glyph has no figure metrics:
        // it is fitted to the bar's icon size so every mode reads the same size.
        OpticalText {
          id: label
          visible: !workspaceButton.shown
          anchors.centerIn: parent
          text: workspaceButton.slot === root.slots ? "0" : String(workspaceButton.slot)
          color: Colors.foreground
          pixelSize: Constants.fontBody
          scale: mouse.pressed ? 0.9 : 1

          Behavior on scale {
            NumberAnimation {
              duration: 80
              easing.type: Easing.InOutQuad
            }
          }
        }

        OpticalGlyph {
          visible: workspaceButton.shown
          anchors.fill: parent
          text: root.modeGlyph(root.activeMode)
          fontSize: Constants.fontBody
          paintedSize: Constants.iconSize
          color: Colors.foreground
          scale: mouse.pressed ? 0.9 : 1

          Behavior on scale {
            NumberAnimation {
              duration: 80
              easing.type: Easing.InOutQuad
            }
          }
        }

        MouseArea {
          id: mouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (workspaceButton.shown) root.cycleLayout()
            else root.focusWorkspace(workspaceButton.modelData)
          }
          onWheel: function(event) { root.scrollWorkspaces(event.angleDelta.y) }
        }
      }
    }
  }
}
