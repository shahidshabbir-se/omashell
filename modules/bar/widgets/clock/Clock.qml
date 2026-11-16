import QtQuick
import qs.common
import qs.config
import "Model.js" as Model

// Date/time label for the bar. Right click walks the common label formats and
// stores the result in shell.json, exactly as the Omarchy clock does, so the
// label shown and the configured format never disagree.
Widget {
  id: root

  signal calendarToggleRequested()

  property var bar: null
  readonly property bool vertical: root.bar ? root.bar.vertical === true : false

  readonly property string formatSettingKey: Model.formatKey(root.vertical)
  readonly property string altFormatSettingKey: Model.altFormatKey(root.vertical)
  readonly property string configuredFormat: Model.formatFromSetting(
    root.setting(root.formatSettingKey, undefined), root.vertical)
  readonly property string configuredAltFormat: Model.altFormatFromSetting(
    root.setting(root.altFormatSettingKey, undefined), root.vertical)

  // What the bar shows is what shell.json stores, so a cycled format survives
  // a restart rather than reverting to a preset index.
  readonly property string activeFormat: root.configuredFormat
  readonly property bool showsSeconds: Model.clockNeedsSeconds(root.activeFormat)

  property date currentDate: new Date()
  readonly property string displayText: root.formatted(root.currentDate)
  readonly property var verticalLines: Model.displayLines(root.displayText)
  readonly property string tooltip: "Right-click to toggle format"

  implicitWidth: root.vertical ? Constants.barHeight : label.implicitWidth
  implicitHeight: root.vertical
    ? Math.max(Constants.iconSlot, root.verticalLines.length * Constants.iconSlot)
    : label.implicitHeight
  readonly property real openPanelIndicatorWidth: label.implicitWidth
  readonly property real openPanelIndicatorHeight: root.vertical
    ? Math.max(10, Math.round(Constants.iconSlot * 0.55))
    : 0

  // Day and month names follow the system locale. The ISO week goes in as a
  // literal because Qt has no ISO week token of its own.
  function formatted(date) {
    var week = Model.isoWeekLiteral(date.getFullYear(), date.getMonth(), date.getDate())
    return date.toLocaleString(Qt.locale(), Model.applyWeek(root.activeFormat, week))
  }

  function cycleFormat() {
    var step = Model.cycleClockFormat(root.settings, root.vertical)
    if (step.next === "" || step.next === step.current) return
    Config.setWidgetSetting(root.widgetId || "clock", step.key, step.next)
  }

  OpticalText {
    id: label

    visible: !root.vertical
    anchors.centerIn: parent
    text: root.vertical ? "" : root.displayText
    pixelSize: Constants.fontBody
    color: Colors.foreground
  }

  Column {
    visible: root.vertical
    anchors.fill: parent

    Repeater {
      model: root.verticalLines

      OpticalGlyph {
        required property string modelData

        width: parent.width
        height: Constants.iconSlot
        text: modelData
        fontFamily: Constants.fontFamily
        fontSize: modelData.length > 3
          ? Constants.fontBody * 0.9
          : Constants.fontBody
        color: Colors.foreground
      }
    }
  }

  Timer {
    id: wallClock

    // A seconds label needs the clock to tick sixty times as often, and a
    // repaint a second is a price only the formats that print seconds pay.
    property int step: root.showsSeconds ? 1000 : 60000

    running: true
    repeat: false

    // Epoch milliseconds never repeat, so a delay stays within one step even
    // in the hour repeated when daylight saving ends.
    function arm() {
      interval = Math.max(1, Model.msUntilNextTick(Date.now(), step))
      restart()
    }

    onStepChanged: arm()
    onTriggered: {
      root.currentDate = new Date()
      arm()
    }
    Component.onCompleted: {
      root.currentDate = new Date()
      arm()
    }
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor

    onClicked: function(mouse) {
      if (mouse.button === Qt.LeftButton) root.calendarToggleRequested()
      else if (mouse.button === Qt.RightButton) root.cycleFormat()
    }
  }
}
