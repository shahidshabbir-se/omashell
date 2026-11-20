import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.common
import qs.config
import "ClipboardModel.js" as ClipboardModel

Scope {
  id: root

  property bool captureEnabled: false
  property bool opened: false
  property var output: null
  property var history: []
  property bool confirmClear: false
  property bool confirmSelected: false
  property bool refreshPending: false
  property bool loaded: false
  property string error: ""
  property int selected: 0
  property string imageSource: ""
  readonly property var helper: ["python3", decodeURIComponent(String(Qt.resolvedUrl("history.py")).replace(/^file:\/\//, ""))]
  readonly property var filters: [
    { id: "all", label: "All" }, { id: "text", label: "Text" },
    { id: "links", label: "Links" }, { id: "colors", label: "Colors" },
    { id: "images", label: "Images" }, { id: "files", label: "Files" }
  ]
  property int filterIndex: 0
  readonly property var results: ClipboardModel.filter(history, filters[filterIndex].id, search.text)
  readonly property var current: results[selected] || null
  readonly property string imageId: opened && current && current.mime === "image/png" ? current.id : ""

  function toggle() {
    if (opened) { close(); return }
    var monitor = Hyprland.focusedMonitor
    output = Quickshell.screens.find(screen => monitor && screen.name === monitor.name) || Quickshell.screens[0] || null
    if (!output) return
    opened = true
    loaded = false
    refresh()
    Qt.callLater(function() { if (root.opened) search.forceActiveFocus() })
  }

  function close() {
    opened = false
    search.clear()
    filterIndex = 0
    confirmClear = false
    selected = 0
    history = []
    error = ""
    refreshPending = false
  }

  function refresh() {
    if (!opened || !captureEnabled) return
    if (reload.running) refreshPending = true
    else reload.running = true
  }

  function selectFilter(index) {
    filterIndex = (index + filters.length) % filters.length
    selected = 0
    list.positionViewAtBeginning()
    search.forceActiveFocus()
  }

  component ColorSwatch: Rectangle {
    property var rgba: null
    color: "white"
    clip: true
    Rectangle { width: parent.width / 2; height: parent.height; color: "#999999" }
    Rectangle {
      anchors.fill: parent
      color: parent.rgba ? Qt.rgba(parent.rgba[0], parent.rgba[1], parent.rgba[2], parent.rgba[3]) : "transparent"
      border.width: 1
      border.color: Colors.muted
    }
  }

  function moveTo(index) {
    if (!results.length) return
    selected = Math.max(0, Math.min(results.length - 1, index))
    list.positionViewAtIndex(selected, ListView.Contain)
  }

  function perform(operation, key) {
    if (!captureEnabled || action.running) return
    error = ""
    action.operation = operation
    action.command = helper.concat(operation === "paste" ? "copy" : operation, key ? [key] : [])
    action.running = true
  }

  function syncWatchers() {
    for (var i = 0; i < watchers.count; i++)
      watchers.objectAt(i).running = captureEnabled
  }

  onCaptureEnabledChanged: {
    syncWatchers()
    if (!captureEnabled) close()
    else refresh()
  }

  onImageIdChanged: {
    imageSource = ""
    loadImage()
  }

  function loadImage() {
    if (!imageId || preview.running) return
    preview.key = imageId
    preview.command = helper.concat("preview", imageId)
    preview.running = true
  }

  Instantiator {
    id: watchers
    model: ["text", "text/uri-list", "image/png"]
    delegate: Process {
      required property string modelData
      command: root.helper.concat("watch", modelData)
      stdout: SplitParser {
        onRead: function(line) {
          if (root.opened && line === "changed" && !captureDebounce.running) captureDebounce.start()
        }
      }
      stderr: SplitParser {} // Do not log backend output from watch callbacks.
    }
    onObjectAdded: function(index, object) { object.running = root.captureEnabled }
  }

  Timer {
    interval: 5000
    repeat: true
    running: root.captureEnabled
    onTriggered: root.syncWatchers()
  }

  Timer {
    id: captureDebounce
    interval: 100
    onTriggered: root.refresh()
  }

  Process {
    id: reload
    command: root.helper.concat("list")
    stdout: StdioCollector { id: historyOutput }
    onExited: function(code) {
      if (!root.opened) return
      root.loaded = true
      if (code === 0) {
        var oldId = root.current ? root.current.id : ""
        root.history = JSON.parse(historyOutput.text).map(ClipboardModel.classify)
        var index = root.results.findIndex(entry => entry.id === oldId)
        root.selected = index >= 0 ? index : Math.max(0, Math.min(root.selected, root.results.length - 1))
        Qt.callLater(function() { if (root.opened) root.moveTo(root.selected) })
      } else {
        root.error = "Could not read clipboard history."
      }
      if (root.refreshPending) {
        root.refreshPending = false
        Qt.callLater(root.refresh)
      }
    }
  }

  Process {
    id: preview
    property string key: ""
    stdout: StdioCollector { id: imageOutput }
    onExited: function(code) {
      if (key === root.imageId) {
        if (code === 0) root.imageSource = imageOutput.text.trim()
      } else {
        Qt.callLater(root.loadImage)
      }
    }
  }

  Process {
    id: action
    property string operation: ""
    onExited: function(code) {
      if (code !== 0) {
        root.error = "Could not update the clipboard or its history."
      } else if (operation === "copy" || operation === "paste") {
        var paste = operation === "paste" && root.opened
        root.close()
        if (paste) Quickshell.execDetached(root.helper.concat("paste"))
      } else {
        root.refresh()
      }
    }
  }

  Connections {
    target: Quickshell
    function onScreensChanged() {
      if (root.opened && !Quickshell.screens.includes(root.output)) root.close()
    }
  }

  PanelWindow {
    id: window
    visible: root.opened
    screen: root.output
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "omashell-clipboard"
    WlrLayershell.keyboardFocus: root.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle { anchors.fill: parent; color: "#aa000000" }
    MouseArea { anchors.fill: parent; onClicked: root.close() }

    Rectangle {
      anchors.centerIn: parent
      width: Math.min(875, parent.width - 24)
      height: Math.min(600, parent.height - 24)
      color: Colors.background
      border.color: Colors.accent
      border.width: 2
      radius: Constants.cornerRadius
      clip: true
      MouseArea { anchors.fill: parent }

      ColumnLayout {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 14

        Item {
          Layout.fillWidth: true
          implicitHeight: 36

          Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "Search clipboard…"
            visible: !search.text
            color: Colors.foreground
            opacity: 0.65
            font: search.font
          }

          TextInput {
            id: search
            anchors.fill: parent
            focus: true
            clip: true
            verticalAlignment: TextInput.AlignVCenter
            color: Colors.foreground
            selectionColor: Colors.accent
            selectedTextColor: Colors.background
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontHeading
            maximumLength: 512
            onTextChanged: { root.selected = 0; list.positionViewAtBeginning() }

            Keys.onPressed: function(event) {
              event.accepted = true
              if (root.confirmClear) {
                if (event.key === Qt.Key_Escape) root.confirmClear = false
                else if (event.key === Qt.Key_Left) root.confirmSelected = false
                else if (event.key === Qt.Key_Right) root.confirmSelected = true
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                  root.confirmClear = false
                  if (root.confirmSelected) root.perform("clear")
                }
                return
              }
              var ctrl = event.modifiers === Qt.ControlModifier
              var up = event.key === Qt.Key_Up || (ctrl && event.key === Qt.Key_K)
              var down = event.key === Qt.Key_Down || (ctrl && event.key === Qt.Key_J)
              if (event.key === Qt.Key_Escape) {
                if (text) clear()
                else if (root.filterIndex) root.selectFilter(0)
                else root.close()
              } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                var backwards = event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier)
                root.selectFilter(root.filterIndex + (backwards ? -1 : 1))
              } else if (up || down) {
                var count = root.results.length
                if (count) root.moveTo((root.selected + (up ? -1 : 1) + count) % count)
              } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
                root.moveTo(root.selected + (event.key === Qt.Key_PageUp ? -6 : 6))
              } else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) {
                root.confirmSelected = false
                root.confirmClear = root.history.length > 0
              } else if (event.key === Qt.Key_Delete && root.current) {
                root.perform("delete", root.current.id)
              } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && root.current) {
                if (event.modifiers & Qt.AltModifier) return
                root.perform(event.modifiers & Qt.ShiftModifier ? "copy" : "paste", root.current.id)
              } else {
                event.accepted = false
              }
            }
          }
        }

        Flow {
          Layout.fillWidth: true
          spacing: 6
          visible: root.captureEnabled && !root.confirmClear
          Repeater {
            model: root.filters
            delegate: Button {
              required property int index
              required property var modelData
              text: modelData.label
              selected: index === root.filterIndex
              onActivated: root.selectFilter(index)
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          Layout.fillHeight: true
          spacing: 14
          visible: root.results.length > 0 && !root.confirmClear

          ListView {
            id: list
            Layout.fillHeight: true
            Layout.preferredWidth: (parent.width - 29) / 2
            clip: true
            spacing: 4
            boundsBehavior: Flickable.StopAtBounds
            model: root.results
            currentIndex: root.selected
            delegate: Rectangle {
              id: row
              required property int index
              required property var modelData
              width: ListView.view.width
              height: 48
              color: index === root.selected ? Colors.selection : hover.hovered ? Colors.lighterBackground : "transparent"
              HoverHandler { id: hover }

              ColorSwatch {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                width: 24
                height: 24
                rgba: row.modelData.rgba
                visible: !!rgba
              }

              Text {
                anchors.fill: parent
                anchors.leftMargin: row.modelData.rgba ? 46 : 12
                anchors.rightMargin: 12
                text: (row.modelData.mime === "image/png" ? "󰋩  " : row.modelData.mime === "text/uri-list" ? "󰈙  " : "")
                  + row.modelData.preview.replace(/\s+/g, " ")
                textFormat: Text.PlainText
                elide: Text.ElideRight
                verticalAlignment: Text.AlignVCenter
                font.family: Constants.fontFamily
                font.pixelSize: Constants.fontTitle
                color: row.index === root.selected ? Colors.brightForeground : Colors.foreground
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onPositionChanged: root.selected = row.index
                hoverEnabled: true
                onClicked: function(event) {
                  root.perform(event.modifiers & Qt.ShiftModifier ? "copy" : "paste", row.modelData.id)
                }
              }
            }
          }

          Rectangle { Layout.fillHeight: true; Layout.preferredWidth: 1; color: Colors.muted }

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            ColumnLayout {
              anchors.fill: parent
              spacing: 10
              ColorSwatch {
                Layout.fillWidth: true
                Layout.preferredHeight: 100
                rgba: root.current ? root.current.rgba : null
                visible: !!rgba
              }
              Text {
                Layout.fillWidth: true
                Layout.fillHeight: true
                text: root.current && !root.imageId ? root.current.preview : ""
                textFormat: Text.PlainText
                wrapMode: Text.WrapAnywhere
                elide: Text.ElideRight
                color: Colors.foreground
                font.family: Constants.fontFamily
                font.pixelSize: Constants.fontTitle
              }
            }
            Image {
              anchors.fill: parent
              visible: !!root.imageId
              source: root.imageSource
              sourceSize.width: Math.max(1, width * 2)
              sourceSize.height: Math.max(1, height * 2)
              fillMode: Image.PreserveAspectFit
              verticalAlignment: Image.AlignTop
              asynchronous: true
              cache: false
            }
          }
        }

        Item {
          Layout.fillWidth: true
          Layout.fillHeight: true
          visible: root.results.length === 0 || root.confirmClear
          ColumnLayout {
            anchors.centerIn: parent
            width: parent.width
            spacing: 14
            Text {
              Layout.fillWidth: true
              text: root.confirmClear ? "Clear all clipboard history?"
                : !root.captureEnabled ? "Set clipboard.enabled to true in Omashell’s shell.json to enable history."
                : !root.loaded ? "Loading clipboard history…"
                : root.history.length === 0 ? "Clipboard history is empty" : "No matches"
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.Wrap
              color: Colors.foreground
              font.family: Constants.fontFamily
              font.pixelSize: Constants.fontTitle
            }
            Row {
              Layout.alignment: Qt.AlignHCenter
              visible: root.confirmClear
              spacing: 10
              Button {
                text: "Cancel"
                selected: !root.confirmSelected
                onActivated: root.confirmClear = false
              }
              Button {
                text: "Clear history"
                selected: root.confirmSelected
                onActivated: { root.confirmClear = false; root.perform("clear") }
              }
            }
          }
        }

        Text {
          Layout.fillWidth: true
          visible: root.captureEnabled
          text: root.error || "↵ Paste   Shift+↵ Copy   Tab Filter   Del Delete   Shift+Del Clear"
          color: root.error ? Colors.red : Colors.foreground
          opacity: root.error ? 1 : 0.68
          wrapMode: Text.Wrap
          font.family: Constants.fontFamily
          font.pixelSize: Constants.fontBodySmall
        }
      }
    }
  }
}
