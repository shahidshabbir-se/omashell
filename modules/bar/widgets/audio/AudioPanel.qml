import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Io
import qs.common
import qs.config
import qs.modules.bar.widgets.audio
import 'Model.js' as Model

PanelShell {
  id: root
  layerNamespace: 'omashell-audio'
  cardWidth: root.width > 0 ? Math.min(380, Math.max(120, root.width - Constants.gap * 2)) : 380
  keyboard: true
  focusTarget: nav
  signal switchPanelRequested(int direction)
  property var outputs: []
  property var inputs: []
  property var streams: []

  function updateRows() {
    if (!opened) return
    var nextOutputs = AudioService.rows('output')
    var nextInputs = AudioService.rows('input')
    var nextStreams = AudioService.rows('stream')
    var changed = false
    if (JSON.stringify(outputs) !== JSON.stringify(nextOutputs)) { outputs = nextOutputs; changed = true }
    if (JSON.stringify(inputs) !== JSON.stringify(nextInputs)) { inputs = nextInputs; changed = true }
    if (JSON.stringify(streams) !== JSON.stringify(nextStreams)) { streams = nextStreams; changed = true }
    if (changed) Qt.callLater(nav.refresh)
  }
  function resetNavigation() {
    nav.refresh()
    var target = 0
    for (var i = 0; i < nav.items.length; i++)
      if (nav.items[i].navigationKey === 'audio-output') { target = i; break }
    nav.reset(target)
  }
  function ensureVisible() {
    var item = nav.current
    if (!item || !viewport.height) return
    var y = item.mapToItem(content, 0, 0).y
    if (y < viewport.contentY) viewport.contentY = Math.max(0, y)
    else if (y + item.height > viewport.contentY + viewport.height)
      viewport.contentY = Math.min(Math.max(0, viewport.contentHeight - viewport.height), y + item.height - viewport.height)
  }
  onOpenedChanged: {
    if (opened) {
      updateRows()
      if (!availabilityProc.running) availabilityProc.running = true
      viewport.contentY = 0
      refreshRows.restart()
      Qt.callLater(root.resetNavigation)
    } else {
      refreshRows.stop()
      outputs = []
      inputs = []
      streams = []
    }
  }
  Connections {
    target: AudioService
    function onNodesChanged() { if (root.opened) refreshRows.restart() }
    function onTrackedChanged() { if (root.opened) refreshRows.restart() }
    function onOutputAvailabilityChanged() { if (root.opened) refreshRows.restart() }
    function onSinkChanged() { if (root.opened) refreshRows.restart() }
  }
  Timer { id: refreshRows; interval: 100; onTriggered: root.updateRows() }
  Timer { interval: 2000; repeat: true; running: root.opened; onTriggered: root.updateRows() }
  Timer { interval: 5000; repeat: true; running: root.opened; onTriggered: if (!availabilityProc.running) availabilityProc.running = true }
  Process {
    id: availabilityProc
    command: ['pactl', '-f', 'json', 'list', 'sinks']
    stdout: StdioCollector {
      onStreamFinished: if (text.trim() !== '') AudioService.outputAvailability = Model.outputAvailability(text)
    }
  }
  PwNodePeakMonitor {
    id: inputPeak
    node: AudioService.source
    enabled: root.opened && AudioService.hasInput
  }

  Flickable {
    id: viewport
    width: parent.width
    height: Math.min(content.implicitHeight, Math.max(100, Math.min(560, root.height - Constants.barHeight - Constants.gap * 2 - Constants.panelPadding * 2 - 4)))
    contentWidth: width
    contentHeight: content.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    Column {
      id: content
      width: viewport.width
      spacing: 14
      PanelHeader {
        width: parent.width
        icon: AudioService.icon
        title: 'Audio'
        caption: AudioService.caption
        rotating: false
        switchVisible: AudioService.hasOutput || AudioService.hasInput
        switchChecked: AudioService.anyAudible
        panelNav: nav
        switchNavigationKey: 'audio-switch'
        switchOnTooltip: 'Unmute'
        switchOffTooltip: 'Mute'
        onSwitchToggled: AudioService.toggleAll()
      }
      PanelSeparator { width: parent.width; pixelRatio: root.devicePixelRatio }
      Column {
        width: parent.width
        spacing: 6
        Item {
          width: parent.width
          implicitHeight: Math.max(outputLabel.implicitHeight, outputValue.implicitHeight)
          SectionLabel { id: outputLabel; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: parent.width - outputValue.width - 10; text: 'Output' }
          Text {
            id: outputValue
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round((outputSlider.dragging ? outputSlider.liveValue : AudioService.outputVolume) * 100) + '%'
            opacity: AudioService.outputMuted ? 0.5 : 1
            color: Qt.darker(Colors.foreground, 1.4)
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontCaption
            font.bold: true
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
          }
        }
        AudioSlider {
          id: outputSlider
          width: parent.width
          navigationKey: 'audio-output'
          panelNav: nav
          navigable: AudioService.hasOutput
          enabled: AudioService.hasOutput
          value: AudioService.outputVolume
          opacity: AudioService.outputMuted ? 0.5 : 1
          onMoved: function(value) { AudioService.setVolume(AudioService.sink, value, 1) }
          onMuteRequested: AudioService.toggleMute(AudioService.sink)
        }
        Text {
          visible: !AudioService.hasOutput
          width: parent.width
          text: 'No audio output available'
          color: Qt.darker(Colors.foreground, 1.4)
          font.family: Constants.fontFamily
          font.pixelSize: Constants.fontBodySmall
          textFormat: Text.PlainText
        }
        Repeater {
          model: root.outputs
          DeviceRow {
            required property var modelData
            width: content.width
            row: modelData
            panelNav: nav
          }
        }
      }
      PanelSeparator { width: parent.width; visible: root.inputs.length > 0 || AudioService.hasInput; pixelRatio: root.devicePixelRatio }
      Column {
        width: parent.width
        visible: root.inputs.length > 0 || AudioService.hasInput
        spacing: 6
        Item {
          width: parent.width
          implicitHeight: Math.max(inputLabel.implicitHeight, inputValue.implicitHeight)
          SectionLabel { id: inputLabel; anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter; width: parent.width - inputValue.width - 10; text: 'Input' }
          Text {
            id: inputValue
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: Math.round((inputSlider.dragging ? inputSlider.liveValue : AudioService.inputVolume) * 100) + '%'
            opacity: AudioService.inputMuted ? 0.5 : 1
            color: Qt.darker(Colors.foreground, 1.4)
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontCaption
            font.bold: true
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
          }
        }
        Column {
          width: parent.width
          spacing: 5
          AudioSlider {
            id: inputSlider
            width: parent.width
            navigationKey: 'audio-input'
            panelNav: nav
            navigable: AudioService.hasInput
            enabled: AudioService.hasInput
            value: AudioService.inputVolume
            opacity: AudioService.inputMuted ? 0.5 : 1
            onMoved: function(value) { AudioService.setVolume(AudioService.source, value, 1) }
            onMuteRequested: AudioService.toggleMute(AudioService.source)
          }
          Rectangle {
            x: 6
            width: parent.width - 12
            height: 5
            color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.18)
            opacity: AudioService.inputMuted ? 0.35 : 1
            Rectangle {
              width: parent.width * Math.max(0, Math.min(1, inputPeak.peak))
              height: parent.height
              color: Colors.foreground
              Behavior on width { NumberAnimation { duration: 70 } }
            }
          }
        }
        Repeater {
          model: root.inputs
          DeviceRow {
            required property var modelData
            width: content.width
            row: modelData
            input: true
            panelNav: nav
          }
        }
      }
      PanelSeparator { width: parent.width; visible: root.streams.length > 0; pixelRatio: root.devicePixelRatio }
      Column {
        width: parent.width
        visible: root.streams.length > 0
        spacing: 10
        SectionLabel { width: parent.width; text: 'Sources' }
        Repeater {
          model: root.streams
          StreamRow {
            required property var modelData
            width: content.width
            row: modelData
            panelNav: nav
          }
        }
      }
    }
  }
  PanelNav {
    id: nav
    container: content
    customNavigation: true
    onCanceled: root.close()
    onTabRequested: function(direction) { root.switchPanelRequested(direction) }
    onMoveRequested: function(dx, dy) {
      if (!nav.cursorActive) { nav.cursorActive = true; return }
      if (dy !== 0) nav.setIndex(nav.index + dy)
      else if (dx !== 0 && nav.current && typeof nav.current.adjust === 'function') nav.current.adjust(dx)
    }
    onTextRequested: function(text) {
      if (nav.cursorActive && (text === 'm' || text === 'M')) {
        if (nav.current && typeof nav.current.toggleMute === 'function') nav.current.toggleMute()
        else AudioService.toggleMute(AudioService.sink)
      }
    }
    onCurrentChanged: Qt.callLater(root.ensureVisible)
  }
}
