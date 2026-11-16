import QtQuick
import Quickshell
import qs.config
import qs.modules.bar
import qs.modules.notifications

// Offscreen wiring harness for the parts of the bar that do not require a
// Wayland panel backend: BarSection -> WidgetRegistry -> Clock / Indicators,
// the Config -> widget settings injection, horizontal/vertical layout, and
// the Clock -> Config format write. It runs with a disposable HOME,
// XDG_CONFIG_HOME and XDG_STATE_HOME; see run-integration.sh.
ShellRoot {
  id: harness

  property int failures: 0
  property int ticks: 0
  property bool tested: false
  property bool cycling: false
  property string beforeDisplay: ""
  property string beforeFormat: ""

  function check(ok, message) {
    console.log((ok ? "CHECK OK: " : "CHECK FAIL: ") + message)
    if (!ok) harness.failures++
  }

  function fail(message) {
    console.log("TEST FAIL: " + message)
    Qt.exit(1)
  }

  function pass(message) {
    console.log("TEST PASS: " + message)
    Qt.exit(0)
  }

  function collect(item, out) {
    out.push(item)
    for (var i = 0; i < item.children.length; i++) harness.collect(item.children[i], out)
    return out
  }

  function findWidget(root, id) {
    var all = harness.collect(root, [])
    for (var i = 0; i < all.length; i++) {
      // The delegate Item also carries widgetId; the loaded widget is the
      // object that received the settings binding.
      if (all[i].widgetId === id && all[i].settings !== undefined) return all[i]
    }
    return null
  }

  function findIndicatorButton(root, id) {
    var all = harness.collect(root, [])
    for (var i = 0; i < all.length; i++)
      if (all[i].indicatorId === id && all[i].glyph !== undefined) return all[i]
    return null
  }

  function findGlyph(root, id) {
    var button = harness.findIndicatorButton(root, id)
    if (!button) return null
    var all = harness.collect(button, [])
    for (var i = 0; i < all.length; i++)
      if (all[i].paintedWidth !== undefined && all[i].text === button.glyph) return all[i]
    return null
  }

  QtObject {
    id: horizontalBar
    property bool vertical: false
    property string position: "top"
    property var widgetDrag: null
    property var contentItem: null
    function roomLength(region, place) { return 0 }
  }

  QtObject {
    id: verticalBar
    property bool vertical: true
    property string position: "left"
    property var widgetDrag: null
    property var contentItem: null
    function roomLength(region, place) { return 0 }
  }

  BarSection {
    id: horizontalSection
    bar: horizontalBar
    ids: ["clock"]
    sectionName: "center"
    screen: Quickshell.screens[0]
  }

  BarSection {
    id: verticalSection
    bar: verticalBar
    ids: ["clock"]
    sectionName: "center"
    screen: Quickshell.screens[0]
  }

  BarSection {
    id: horizontalIndicators
    bar: horizontalBar
    ids: ["indicators"]
    sectionName: "centerBegin"
    screen: Quickshell.screens[0]
  }

  BarSection {
    id: verticalIndicators
    bar: verticalBar
    ids: ["indicators"]
    sectionName: "centerEnd"
    screen: Quickshell.screens[0]
  }

  Timer {
    id: timeout
    interval: 10000
    running: !harness.tested
    onTriggered: harness.fail("timeout waiting for bar widgets")
  }

  Timer {
    interval: 20
    repeat: true
    running: !harness.tested
    onTriggered: {
      harness.ticks++
      if (!Config.configReady) return

      var clockH = harness.findWidget(horizontalSection, "clock")
      var clockV = harness.findWidget(verticalSection, "clock")
      var indH = harness.findWidget(horizontalIndicators, "indicators")
      var indV = harness.findWidget(verticalIndicators, "indicators")
      if (!clockH || !clockV || !indH || !indV) return
      if (clockH.displayText === undefined || clockV.displayText === undefined) return

      if (!harness.cycling) {
        harness.testInitial(clockH, clockV, indH, indV)
        harness.cycling = true
        harness.beforeDisplay = String(clockH.displayText)
        harness.beforeFormat = String(clockH.settings.format)
        clockH.cycleFormat()
        return
      }

      // Clock -> Config.setWidgetSetting -> BarSection settings binding.
      if (clockH.settings.format === harness.beforeFormat) {
        if (harness.ticks > 200) harness.fail("clock format did not update after cycle")
        return
      }
      harness.check(clockH.displayText !== harness.beforeDisplay, "clock display follows cycled format")
      harness.check(Config.raw && Config.raw.bar && Config.raw.bar.center &&
        Config.raw.bar.center[0] && Config.raw.bar.center[0].format !== undefined,
        "clock cycle writes the bar layout")
      harness.finish()
    }
  }

  function testInitial(clockH, clockV, indH, indV) {
    harness.check(Config.bar.position === "top", "config position is top")
    harness.check(clockH.vertical === false, "horizontal clock sees horizontal bar")
    harness.check(clockV.vertical === true, "vertical clock sees vertical bar")
    harness.check(clockH.bar === horizontalBar, "clock bar injected")
    harness.check(clockH.widgetId === "clock", "clock widgetId injected")
    harness.check(clockH.settings && clockH.settings.format === "HH:mm:ss", "clock settings injected from config")
    harness.check(clockH.showsSeconds === true, "clock seconds from config")
    harness.check(clockH.displayText.length > 0 && clockH.displayText.indexOf(":") >= 0, "horizontal clock text")
    harness.check(clockH.implicitWidth > 0 && clockH.implicitHeight > 0, "horizontal clock has geometry")
    harness.check(clockV.displayText.indexOf("\n") >= 0, "vertical clock text has lines")
    harness.check(clockV.verticalLines.length >= 2, "vertical clock lines")
    harness.check(horizontalSection.width > 0 && horizontalSection.height === 28, "horizontal section geometry")
    harness.check(verticalSection.width === 28 && verticalSection.implicitHeight > 0, "vertical section geometry")

    harness.check(indH.available === true, "horizontal indicators available")
    harness.check(indH.displayed.length === 2, "horizontal indicators display two")
    harness.check(indH.vertical === false, "horizontal indicators orientation")
    harness.check(indH.bar === horizontalBar, "horizontal indicators bar injected")
    harness.check(indH.fixedEdge === "end", "centerBegin indicators fixedEdge is end")
    harness.check(indH.settings && indH.settings.items && indH.settings.items.length === 2, "indicator settings injected")

    harness.check(indV.available === true, "vertical indicators available")
    harness.check(indV.vertical === true, "vertical indicators orientation")
    harness.check(indV.bar === verticalBar, "vertical indicators bar injected")
    harness.check(indV.fixedEdge === "start", "centerEnd indicators fixedEdge is start")
    harness.check(indV.displayed.length === 2, "vertical indicators display two")

    var dndButton = harness.findIndicatorButton(indH, "Dnd")
    var awakeButton = harness.findIndicatorButton(indH, "StayAwake")
    harness.check(!!dndButton && !!awakeButton, "both indicator buttons rendered")
    if (dndButton) {
      var glyph = harness.findGlyph(indH, "Dnd")
      harness.check(dndButton.implicitWidth === 21 && dndButton.implicitHeight === 26, "horizontal indicator slot geometry")
      harness.check(!!glyph && glyph.paintedWidth > 0 && glyph.paintedHeight > 0, "Dnd glyph has painted bounds")
      if (glyph) {
        harness.check(Math.abs(glyph.paintedCenterX - dndButton.width / 2) <= 0.51, "Dnd glyph horizontally centered")
        harness.check(Math.abs(glyph.paintedCenterY - dndButton.height / 2) <= 0.51, "Dnd glyph vertically centered")
      }
    }
    var vButton = harness.findIndicatorButton(indV, "Dnd")
    if (vButton) {
      harness.check(vButton.implicitWidth === 28 && vButton.implicitHeight === 21, "vertical indicator slot geometry")
      harness.check(vButton.opacity === 1 || vButton.opacity === 0.45, "inactive indicator opacity")
      var buttonParts = harness.collect(vButton, [])
      var buttonArea = null
      for (var i = 0; i < buttonParts.length; i++)
        if (buttonParts[i].acceptedButtons !== undefined) buttonArea = buttonParts[i]
      harness.check(!!buttonArea && (buttonArea.acceptedButtons & Qt.RightButton) !== 0, "indicator accepts right-click")
      harness.check(!!buttonArea && (buttonArea.acceptedButtons & Qt.MiddleButton) !== 0, "indicator accepts middle-click")
    }

    // DND is a real service toggle, but the harness's state file is disposable.
    indH.activate("Dnd")
    harness.check(NotificationService.dnd === true, "Dnd indicator toggles NotificationService")
    NotificationService.toggleDnd()
    harness.check(NotificationService.dnd === false, "Dnd indicator toggles back")
  }

  function finish() {
    harness.tested = true
    timeout.stop()
    console.log("RESULT failures=" + harness.failures)
    if (harness.failures === 0) harness.pass("BarSection Clock/Indicators wiring")
    else harness.fail(harness.failures + " integration checks failed")
  }
}
