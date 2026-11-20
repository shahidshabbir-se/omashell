import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.common
import qs.config

PanelShell {
  id: root

  layerNamespace: "omashell-display"
  cardWidth: Constants.scaledFont(380)
  contentPadding: Constants.scaledFont(14)
  spacing: Constants.scaledFont(14)
  readonly property int controlGap: Constants.scaledFont(6)
  readonly property int trackInset: controlGap
  readonly property int thumbSize: Math.max(14, Constants.scaledFont(14))
  readonly property int trackHeight: Math.max(4, Constants.scaledFont(4))
  readonly property int sliderHeight: Math.max(Constants.scaledFont(22), thumbSize + controlGap) + Constants.scaledFont(8)
  readonly property int sliderInset: Math.round((sliderHeight - trackHeight) / 2)
  keyboard: true
  onOpenedChanged: if (!opened) cancelPreview()
  onProfilePathChanged: if (opened || token) dismiss()

  Shortcut {
    sequence: "Escape"
    context: Qt.WindowShortcut
    enabled: root.opened
    onActivated: root.dismiss()
  }

  Shortcut {
    sequence: "R"
    context: Qt.WindowShortcut
    enabled: root.opened && root.editing && !!root.info
    onActivated: rotationSection.focusChoice(root.rotationIndex)
  }

  property string profilePath: ""
  property var info: null
  property string message: ""
  property bool failed: false
  property string token: ""
  property string phase: ""
  property string pendingDecision: ""
  property int seconds: 0
  property int modeIndex: -1
  property int rateIndex: -1
  property int scaleIndex: -1
  property int rotationIndex: 0
  readonly property bool builtInScreen: !!screen && /^(eDP|LVDS|DSI)-[0-9]+$/.test(screen.name)
  readonly property var shownModes: {
    if (!info) return []
    const all = info.options
    if (!builtInScreen) return all
    const nativeMode = all[all.length - 1]
    if (!nativeMode) return []
    const ratio = nativeMode.width / nativeMode.height
    const common = all.filter(option => option.height >= 1080 && Math.abs(option.width / option.height - ratio) < 0.01).slice(-4)
    const live = all.find(option => option.width === info.live.width && option.height === info.live.height)
    if (live && !common.includes(live)) common.push(live)
    return common.sort((a, b) => a.width * a.height - b.width * b.height)
  }
  readonly property var mode: modeIndex >= 0 ? shownModes[modeIndex] || null : null
  readonly property bool editing: !token && !task.running && phase === ""
  readonly property bool changed: !!mode && (!info.initialized || mode.width !== info.live.width
    || mode.height !== info.live.height || Math.abs(mode.rates[rateIndex] - info.live.refreshRate) > 0.006
    || Math.abs(mode.scales[scaleIndex] - info.live.scale) > 0.0001 || rotationIndex !== info.live.transform)
  readonly property bool confirmable: phase === "preview" && !pendingDecision && seconds > 0
  readonly property var helper: ["python3", decodeURIComponent(String(Qt.resolvedUrl("display.py")).replace(/^file:\/\//, ""))]

  function toggle() {
    if (opened) { dismiss(); return }
    var focused = Hyprland.focusedMonitor
    screen = Quickshell.screens.find(s => focused && s.name === focused.name) || Quickshell.screens[0] || null
    if (!screen) return
    open()
    if (builtInScreen) Backlight.read()
    if (!token && !task.running) load(false)
  }

  function dismiss() {
    if (opened) close()
    else cancelPreview()
  }

  function cancelPreview() {
    if (phase === "launching" || (token && !pendingDecision)) pendingDecision = "cancel"
    if (pendingDecision) advance()
  }

  function run(operation, args) {
    task.operation = operation
    task.command = helper.concat(operation, args)
    task.running = true
  }

  function load(preserveMessage) {
    info = null
    if (!preserveMessage) { message = ""; failed = false }
    if (Quickshell.screens.length !== 1) {
      message = "Display previews are only supported with one connected display."
      return
    }
    if (!profilePath) {
      message = "Set display.profilePath or display.standalonePath to a writable display profile to enable previews."
      return
    }
    run("inspect", [profilePath])
  }

  function closest(values, reference, tolerance) {
    var match = values.findIndex(value => Math.abs(value - reference) < tolerance)
    return match >= 0 ? match : (values.length ? 0 : -1)
  }

  function resolutionCaption(option) {
    return option ? option.width + "×" + option.height : ""
  }

  function resolutionPills(options) {
    // Use short sizes unless two advertised modes share the same height.
    return options.map(option => {
      if (options.filter(other => other.height === option.height).length > 1) return resolutionCaption(option)
      if (option.width === 3840 && option.height === 2160) return "4K"
      if (option.width === 7680 && option.height === 4320) return "8K"
      return option.height + "p"
    })
  }

  function selectMode(index, referenceRate, referenceScale) {
    modeIndex = index
    rateIndex = mode ? closest(mode.rates, referenceRate, 0.006) : -1
    scaleIndex = mode ? closest(mode.scales, referenceScale, 0.0001) : -1
  }

  function preview() {
    if (!opened || !editing || !changed || !mode || rateIndex < 0 || scaleIndex < 0) return
    message = ""
    failed = false
    phase = "launching"
    run("start", [profilePath, JSON.stringify({version: 1, connector: info.live.connector,
      width: mode.width, height: mode.height, refreshRate: mode.rates[rateIndex], scale: mode.scales[scaleIndex],
      transform: rotationIndex})])
  }

  function choose(action) {
    if (!token || pendingDecision) return
    pendingDecision = action
    advance()
  }

  function advance() {
    if (task.running || !token) return
    if (pendingDecision && phase !== "deciding") {
      phase = "deciding"
      run(pendingDecision, [token])
    } else {
      run("status", [token])
    }
  }

  Timer {
    interval: 250
    repeat: true
    running: !!root.token
    onTriggered: root.advance()
  }

  Timer {
    interval: 4000
    repeat: true
    running: root.opened && root.builtInScreen
    onTriggered: Backlight.read()
  }

  Process {
    id: textTask
    property int requestedSize: 12
    onExited: function(code) {
      if (code === 0) Constants.textSize = requestedSize
      else { root.failed = true; root.message = "Could not save the Omashell text size." }
    }
  }

  Process {
    id: task
    property string operation: ""
    stdout: StdioCollector { id: result }
    stderr: StdioCollector {}
    onExited: function(code) {
      var data
      try { data = JSON.parse(result.text) } catch (_) { data = {} }
      var op = operation
      if (code !== 0 || !data || typeof data !== "object") {
        root.message = (data && data.error) || "Could not contact the display helper. Unconfirmed settings will time out."
        root.failed = true
        if (op === "status" || op === "start") {
          root.token = ""
          root.phase = ""
          root.pendingDecision = ""
        }
        return
      }
      if (op === "inspect") {
        if (!data.options || !data.live) return
        root.info = data
        if (root.builtInScreen) Backlight.read()
        var live = data.live
        root.rotationIndex = live.transform || 0
        var index = root.shownModes.findIndex(option => option.width === live.width && option.height === live.height)
        root.selectMode(Math.max(0, index), live.refreshRate, live.scale)
        Qt.callLater(function() {
          if (!root.opened || !root.editing) return
          if (brightnessRow.visible) brightnessSlider.forceActiveFocus(Qt.OtherFocusReason)
          else if (root.scaleIndex >= 0) scaleSection.focusChoice(root.scaleIndex, Qt.OtherFocusReason)
        })
      } else if (op === "start") {
        if (!data.token) { root.phase = ""; root.pendingDecision = ""; return }
        root.token = data.token
        root.phase = "starting"
        Qt.callLater(root.advance)
      } else if (op === "status") {
        if (data.state === "starting" || data.state === "applying" || data.state === "preview") {
          if (root.phase !== "deciding") root.phase = data.state
          root.seconds = data.seconds || 0
          if (root.pendingDecision && root.phase !== "deciding") Qt.callLater(root.advance)
        } else {
          root.token = ""
          root.phase = ""
          root.pendingDecision = ""
          root.failed = data.state === "error"
          root.message = root.failed ? (data.message || "Display preview failed.") : ""
          if (root.opened) Qt.callLater(function() { if (root.opened && !task.running) root.load(true) })
        }
      }
    }
  }

  component Label: Text {
    color: Colors.foreground
    font.family: Constants.fontFamily
    font.pixelSize: Constants.fontBody
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
  }

  component ActionButton: Controls.Button {
    id: button
    property bool primary: false
    property bool pill: false
    padding: pill ? 6 : 8
    leftPadding: pill ? 3 : 14
    rightPadding: pill ? 3 : 14
    font.family: Constants.fontFamily
    font.pixelSize: Constants.fontBody
    contentItem: Label {
      text: button.text
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      wrapMode: Text.NoWrap
      font.pixelSize: button.pill ? Constants.fontCaption : Constants.fontBody
      opacity: button.enabled || button.pill ? 1 : 0.5
    }
    background: Rectangle {
      radius: Constants.cornerRadius
      color: button.down || button.primary ? Colors.selection
        : button.hovered || !button.pill ? Colors.lighterBackground : "transparent"
      border.width: button.pill || button.visualFocus || button.hovered ? 1 : 0
      border.color: button.visualFocus ? Colors.accent
        : Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, button.hovered ? 0.48 : 0.27)
    }
  }

  component SectionHeading: RowLayout {
    id: heading
    property string title: ""
    property string valueLabel: ""
    width: parent.width
    spacing: 8

    Label {
      Layout.fillWidth: true
      text: heading.title.toUpperCase()
      color: Qt.darker(Colors.foreground, 1.4)
      font.pixelSize: Constants.fontCaption
      font.bold: true
    }
    Label {
      visible: !!text
      text: heading.valueLabel
      color: Qt.darker(Colors.foreground, 1.4)
      font.pixelSize: Constants.fontCaption
      font.bold: true
    }
  }

  component ChoiceSection: Column {
    id: section
    property string title
    property var choices: []
    property string valueLabel: choices[selected] || ""
    property int selected: -1
    property int pillWidth: 44
    signal chosen(int index)

    width: parent.width
    spacing: root.controlGap + root.sliderInset
    bottomPadding: root.sliderInset
    enabled: root.editing

    function focusChoice(index, reason) {
      var item = pills.itemAt(index)
      if (item) item.forceActiveFocus(reason === undefined ? Qt.TabFocusReason : reason)
    }

    SectionHeading {
      title: section.title
      valueLabel: section.valueLabel
    }

    Grid {
      id: grid
      width: parent.width
      spacing: Constants.scaledFont(3)
      columns: Math.max(1, Math.min(section.choices.length, Math.floor((width + spacing) / (section.pillWidth + spacing))))

      Repeater {
        id: pills
        model: section.choices
        ActionButton {
          id: choice
          required property int index
          required property string modelData
          width: (grid.width - grid.spacing * (grid.columns - 1)) / grid.columns
          pill: true
          primary: index === section.selected
          text: modelData
          Accessible.name: section.title + ": " + text
          onClicked: section.chosen(index)
          Keys.onLeftPressed: section.focusChoice(index - 1)
          Keys.onRightPressed: section.focusChoice(index + 1)
          Keys.onUpPressed: section.focusChoice(index - grid.columns)
          Keys.onDownPressed: section.focusChoice(index + grid.columns)
        }
      }
    }
  }

  Controls.ScrollView {
    id: viewport
    width: parent.width
    height: Math.min(body.implicitHeight, Math.max(1, root.fitCardHeight(1024, root.height,
      root.verticalBar, Constants.barHeight, Constants.gap) - root.contentPadding * 2 - 4))
    contentWidth: availableWidth
    clip: true
    Controls.ScrollBar.horizontal.policy: Controls.ScrollBar.AlwaysOff

    Column {
      id: body
      width: viewport.availableWidth
      spacing: root.spacing

      PanelHeader {
        width: parent.width
        icon: "󰍹"
        title: root.info ? root.info.name : "Display"
        caption: brightnessRow.visible ? (Backlight.displayValue < 15 ? "Night light"
          : Backlight.displayValue < 35 ? "Lamp light" : Backlight.displayValue < 60 ? "Soft daylight"
          : Backlight.displayValue < 85 ? "Bright daylight" : "Full sun")
          : root.info ? root.resolutionCaption(root.info.live) + " · " + Math.round(root.info.live.refreshRate) + " Hz"
          : "Hyprland monitor settings"
      }

      PanelSeparator { visible: brightnessRow.visible }
      Column {
        id: brightnessRow
        width: parent.width
        spacing: root.controlGap
        visible: root.builtInScreen && Backlight.value >= 0

        SectionHeading {
          title: "Brightness"
          valueLabel: Math.round(brightnessSlider.value) + "%"
        }
        Controls.Slider {
          id: brightnessSlider
          width: parent.width
          implicitHeight: root.sliderHeight
          padding: root.trackInset
          from: 1
          to: 100
          stepSize: 1
          enabled: !root.token && root.phase !== "launching"
          Accessible.name: "Brightness"
          onMoved: Backlight.set(value)
          Binding on value {
            value: Math.max(1, Backlight.displayValue)
            when: !brightnessSlider.pressed
            restoreMode: Binding.RestoreNone
          }
          background: Rectangle {
            radius: Constants.cornerRadius
            color: "transparent"
            Rectangle {
              x: brightnessSlider.leftPadding + root.thumbSize / 2
              width: Math.max(0, brightnessSlider.availableWidth - root.thumbSize)
              height: root.trackHeight
              radius: height / 2
              color: Colors.muted
              anchors.verticalCenter: parent.verticalCenter
              Rectangle {
                width: parent.width * brightnessSlider.visualPosition
                height: parent.height
                radius: parent.radius
                color: Colors.foreground
              }
            }
          }
          handle: Rectangle {
            implicitWidth: root.thumbSize
            implicitHeight: root.thumbSize
            x: brightnessSlider.leftPadding + (brightnessSlider.availableWidth - width) * brightnessSlider.visualPosition
            y: (brightnessSlider.height - height) / 2
            radius: width / 2
            color: Colors.foreground
          }
        }
        Label {
          width: parent.width
          visible: !!text
          color: Colors.red
          text: Backlight.error
        }
      }

      PanelSeparator {}
      Column {
        width: parent.width
        spacing: root.controlGap
        SectionHeading {
          title: "Text size"
          valueLabel: (textSlider.pressed ? Constants.textSizes[Math.round(textSlider.value)] : Constants.textSize) + "px"
        }
        Controls.Slider {
          id: textSlider
          width: parent.width
          implicitHeight: root.sliderHeight
          padding: root.trackInset
          from: 0
          to: Constants.textSizes.length - 1
          stepSize: 1
          snapMode: Controls.Slider.SnapAlways
          enabled: !textTask.running && root.editing
          Accessible.name: "Omashell text size"
          function saveSize() {
            var size = Constants.textSizes[Math.round(value)]
            if (size === Constants.textSize || textTask.running) return
            textTask.requestedSize = size
            textTask.command = root.helper.concat("text-size", String(size))
            textTask.running = true
          }
          onMoved: if (!pressed) saveSize()
          onPressedChanged: if (!pressed) saveSize()
          Binding on value {
            value: Constants.textSizes.indexOf(Constants.textSize)
            when: !textSlider.pressed && !textTask.running
            restoreMode: Binding.RestoreNone
          }
          background: Row {
            id: textTrack
            x: textSlider.leftPadding + root.thumbSize / 2
            y: (textSlider.height - height) / 2
            width: Math.max(0, textSlider.availableWidth - root.thumbSize)
            height: root.trackHeight
            spacing: Constants.scaledFont(2)
            Repeater {
              model: Constants.textSizes.length - 1
              Rectangle {
                required property int index
                width: Math.max(0, (textTrack.width - textTrack.spacing * (Constants.textSizes.length - 2)) / (Constants.textSizes.length - 1))
                height: parent.height
                color: index < textSlider.value ? Colors.foreground : Colors.muted
              }
            }
          }
          handle: Rectangle {
            implicitWidth: root.thumbSize
            implicitHeight: root.thumbSize
            x: textSlider.leftPadding + (textSlider.availableWidth - width) * textSlider.visualPosition
            y: (textSlider.height - height) / 2
            color: Colors.foreground
            radius: width / 2
            border.width: textSlider.visualFocus ? 2 : 0
            border.color: Colors.accent
          }
        }
      }

      Column {
        width: parent.width
        spacing: root.spacing
        visible: !!root.info

        PanelSeparator {}
        ChoiceSection {
          id: scaleSection
          title: "Scale"
          valueLabel: ""
          choices: root.mode ? root.mode.scales.map(scale => parseFloat(scale.toFixed(2)) + "×") : []
          selected: root.scaleIndex
          onChosen: function(index) {
            root.scaleIndex = index
            Qt.callLater(root.preview)
          }
        }
        PanelSeparator { visible: root.shownModes.length > 1 }
        ChoiceSection {
          visible: root.shownModes.length > 1
          title: "Resolution"
          pillWidth: 56
          choices: root.resolutionPills(root.shownModes)
          selected: root.modeIndex
          valueLabel: root.resolutionCaption(root.mode)
          onChosen: function(index) {
            var previous = root.mode
            root.selectMode(index, previous ? previous.rates[root.rateIndex] : 0,
                            previous ? previous.scales[root.scaleIndex] : 1)
            Qt.callLater(root.preview)
          }
        }
        PanelSeparator { visible: root.mode !== null && root.mode.rates.length > 1 }
        ChoiceSection {
          visible: root.mode !== null && root.mode.rates.length > 1
          title: "Refresh rate"
          choices: root.mode ? root.mode.rates.map(rate => String(rate)) : []
          selected: root.rateIndex
          valueLabel: selected >= 0 ? choices[selected] + " Hz" : ""
          onChosen: function(index) {
            root.rateIndex = index
            Qt.callLater(root.preview)
          }
        }
        PanelSeparator {}
        ChoiceSection {
          id: rotationSection
          title: "Rotation"
          choices: ["0°", "90°", "180°", "270°"]
          selected: root.rotationIndex
          onChosen: function(index) {
            root.rotationIndex = index
            Qt.callLater(root.preview)
          }
        }
        PanelSeparator {
          visible: !!root.token || root.phase === "launching" || !!root.message
        }
      }

      Label {
        width: parent.width
        visible: !!text
        color: root.failed ? Colors.red : Colors.foreground
        text: root.phase === "preview" ? "Keep these settings? Reverting in " + root.seconds + "s."
          : root.phase === "deciding" ? "Finishing preview…"
          : root.token || root.phase === "launching" ? "Applying and verifying the display settings…"
          : root.message
      }

      RowLayout {
        width: parent.width
        visible: !!root.token || root.phase === "launching"
        Item { Layout.fillWidth: true }
        ActionButton {
          text: "Revert"
          enabled: !root.pendingDecision
          onClicked: root.cancelPreview()
        }
        ActionButton {
          primary: true
          text: "Keep"
          enabled: root.confirmable
          onClicked: root.choose("keep")
        }
      }
    }
  }
}
