import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import qs.common
import qs.config
import "Model.js" as Model

                                                                                   
                                                                                  
                               
PanelShell {
  id: root

  layerNamespace: "omashell-bluetooth"
  cardWidth: 360
  keyboard: true
  focusTarget: nav

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []
  readonly property var lists: Model.deviceLists(root.devices)
  readonly property bool ready: root.adapter !== null && root.adapter.enabled
  readonly property bool discovering: root.adapter !== null && root.adapter.discovering

  signal switchPanelRequested(int direction)

  function resetNavigation() {
    nav.refresh()
    var items = nav.items
    var start = 0
    for (var i = 0; i < items.length; i++) {
      if (items[i].isDeviceRow === true) { start = i; break }
    }
    nav.reset(start)
  }

  function ensureCurrentVisible() {
    var current = nav.current
    if (!current || current.isDeviceRow !== true || sectionViewport.height <= 0) return
    var y = current.mapToItem(sectionViewport, 0, 0).y
    if (y < 0) sectionViewport.contentY = Math.max(0, sectionViewport.contentY + y)
    else if (y + current.height > sectionViewport.height)
      sectionViewport.contentY = Math.min(sectionViewport.contentHeight - sectionViewport.height,
        sectionViewport.contentY + y + current.height - sectionViewport.height)
  }

  function forget(row) {
    if (!row || !row.address || (row.section !== "known" && row.section !== "connected")) return
    root.enqueue("forget", row.address)
  }

                                                            
  readonly property string icon: root.adapter === null ? ""
    : (!root.adapter.enabled ? "\uDB80\uDCB2"
      : (root.lists.connected.length > 0 ? "\uDB80\uDCB1" : "\uDB80\uDCAF"))

                                                                             
  property var pending: ({})

  readonly property string caption: root.adapter === null
    ? "no adapter"
    : (!root.adapter.enabled
      ? "off"
      : (root.lists.connected.length > 0
        ? root.lists.connected.length + " connected"
        : "on"))

  onOpenedChanged: {
    discovery.active = root.opened
    if (root.opened) Qt.callLater(root.resetNavigation)
  }
  onListsChanged: Qt.callLater(nav.refresh)
  onReadyChanged: Qt.callLater(nav.refresh)
  onDiscoveringChanged: Qt.callLater(nav.refresh)

                                                                                 

  property var queue: []
  property var runningJob: null

  function deviceForAddress(address) {
    var wanted = Model.normalizedAddress(address)
    var values = root.devices
    for (var i = 0; i < values.length; i++) {
      if (Model.normalizedAddress(values[i] && values[i].address) === wanted) return values[i]
    }
    return null
  }

  function act(row) {
    if (!row || row.address === "") return
    var action = Model.actionFor(row)
                                                                                 
    if (action === "disconnect") {
      var device = root.deviceForAddress(row.address)
      if (device && typeof device.disconnect === "function") device.disconnect()
    }
    root.enqueue(action, row.address)
  }

  function enqueue(action, address) {
    if (action === "") return
    var job = { action: action, address: Model.normalizedAddress(address) }
    root.pending = Model.withPending(root.pending, job.address, action)
    pendingTimeout.restart()
    root.queue = root.queue.concat([job])
    if (root.runningJob === null) root.startNext()
  }

  function syncPending() {
    root.pending = Model.syncPending(root.pending, root.devices)
  }

  function actionCommand(job) {
    var address = job.address
    if (job.action === "pair")
      return ["bash", "-c", "timeout 20s bluetoothctl pair \"$1\" >/dev/null 2>&1 || true; bluetoothctl trust \"$1\" >/dev/null 2>&1 || true; timeout 20s bluetoothctl connect \"$1\" >/dev/null 2>&1 || true", "omashell-bluetooth", address]
    if (job.action === "connect")
      return ["bash", "-c", "bluetoothctl trust \"$1\" >/dev/null 2>&1 || true; timeout 20s bluetoothctl connect \"$1\" >/dev/null 2>&1 || true", "omashell-bluetooth", address]
    if (job.action === "disconnect")
      return ["bash", "-c", "timeout 10s bluetoothctl disconnect \"$1\" >/dev/null 2>&1 || true", "omashell-bluetooth", address]
    if (job.action === "forget")
      return ["bash", "-c", "timeout 10s bluetoothctl disconnect \"$1\" >/dev/null 2>&1 || true; timeout 10s bluetoothctl remove \"$1\" >/dev/null 2>&1 || true", "omashell-bluetooth", address]
    return []
  }

  function startNext() {
    if (root.queue.length === 0) {
      root.runningJob = null
      return
    }
    var job = root.queue[0]
    root.queue = root.queue.slice(1)
    root.runningJob = job
    actionProc.command = root.actionCommand(job)
    actionProc.running = true
  }

  Timer {
    id: pendingTimeout
    interval: 20000
    onTriggered: root.pending = ({})
  }

  Timer {
    interval: 500
    repeat: true
    running: Object.keys(root.pending).length > 0
    onTriggered: root.syncPending()
  }

  Process {
    id: actionProc

    onExited: function(code) {
      var job = root.runningJob
      root.runningJob = null
      if (job) {
                                                                              
                                                                     
        root.syncPending()
      }
      root.startNext()
    }
  }

                                                                                 

  Column {
    id: body

    width: parent.width
    spacing: 14

    PanelHeader {
      width: parent.width
      panelNav: nav
      icon: root.icon
      title: "Bluetooth"
      captions: root.adapter === null
        ? ["No adapter"]
        : (!root.adapter.enabled
          ? ["Radio off"]
          : ["Untangling wires", "Streaming vikings", "Pairing mysteries", "Herding headsets",
             "Taming radios", "Summoning speakers", "Wrangling codecs", "Polishing packets"])
      rotating: root.opened && root.adapter !== null && root.adapter.enabled
      switchVisible: root.adapter !== null
      switchChecked: root.adapter !== null && root.adapter.enabled

      onSwitchToggled: if (root.adapter !== null) root.adapter.enabled = !root.adapter.enabled
    }

    PanelSeparator {
      width: parent.width
      pixelRatio: root.devicePixelRatio
    }

    Text {
      visible: !root.ready
      width: parent.width
      text: root.adapter === null ? "No bluetooth adapter" : "Bluetooth is off"
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontBodySmall
      color: Qt.darker(Colors.foreground, 1.5)
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      wrapMode: Text.WordWrap
    }

    Flickable {
      id: sectionViewport

      width: parent.width
      height: Math.min(sections.implicitHeight, 400)
      contentHeight: sections.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height
      visible: root.ready

      Column {
        id: sections
        width: sectionViewport.width
        spacing: 10

        Repeater {
                                                                                
                                                                      
        model: root.ready ? [
          { key: "connected", title: "Connected", rows: root.lists.connected, show: root.lists.connected.length > 0 },
          { key: "known", title: "Paired", rows: root.lists.known, show: root.lists.known.length > 0 },
          { key: "discovered", title: "Available", rows: root.lists.discovered, show: root.discovering && root.lists.discovered.length > 0 }
        ].filter(function(section) { return section.show }) : []

        delegate: Column {
          id: section

          required property var modelData
          required property int index

          width: sections.width
          spacing: 10
          PanelSeparator {
            width: parent.width
            pixelRatio: root.devicePixelRatio
            visible: section.index > 0
            height: visible ? implicitHeight : 0
          }

          SectionLabel {
            width: parent.width
            text: modelData.title
          }

          Repeater {
            model: modelData.rows

            delegate: DeviceRow {
              required property var modelData

              width: section.width
              panelNav: nav
              row: modelData
              pending: root.pending[modelData.address] !== undefined
                ? root.pending[modelData.address]
                : ""

              onActivated: root.act(modelData)
              onForgetRequested: root.forget(modelData)
            }
          }
        }
        }
      }

      Text {
        visible: root.ready && root.lists.connected.length === 0
          && root.lists.known.length === 0 && root.lists.discovered.length === 0
        text: "Scanning…"
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontBodySmall
        color: Qt.darker(Colors.foreground, 1.5)
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
      }
    }
  }

  PanelNav {
    id: nav

    container: body
    onCanceled: root.close()
    onTabRequested: function(direction) { root.switchPanelRequested(direction) }
    onDeleteRequested: {
      if (nav.current && nav.current.isDeviceRow === true) nav.current.forget()
    }
    onTextRequested: function(text) {
      if ((text === "b" || text === "B") && root.adapter !== null)
        root.adapter.enabled = !root.adapter.enabled
    }
    onHorizontalRequested: function(direction) {
      if (nav.current && nav.current.isDeviceRow === true) nav.current.adjust(direction)
    }
    onCurrentChanged: Qt.callLater(root.ensureCurrentVisible)
    onItemsChanged: Qt.callLater(root.ensureCurrentVisible)
  }

  BluetoothDiscovery {
    id: discovery

    adapter: root.adapter
  }
}
