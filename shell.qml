import Quickshell
import Quickshell.Io
import qs.modules.bar
import qs.modules.bar.widgets.clock
import qs.modules.bar.widgets.weather
import qs.modules.bar.widgets.worldclock
import qs.modules.bar.widgets.bluetooth
import qs.modules.visualizer
import qs.config

ShellRoot {
  id: shell

  // The only place that maps a bar widget id to its panel. Keys match the ids in
  // config/shell.json and WidgetRegistry.
  readonly property var panelFor: ({
    clock: calendarPanel,
    weather: weatherPanel,
    worldclock: worldClockPanel,
    bluetooth: bluetoothPanel
  })

  function closePanels() {
    calendarPanel.close()
    weatherPanel.close()
    worldClockPanel.close()
    bluetoothPanel.close()
  }

  function showPanel(target, x) {
    if (target !== calendarPanel) calendarPanel.close()
    if (target !== weatherPanel) weatherPanel.close()
    if (target !== worldClockPanel) worldClockPanel.close()
    if (target !== bluetoothPanel) bluetoothPanel.close()
    target.anchorX = x
    target.toggle()
  }

  // Unknown id (no panel) is a no-op, not an error.
  function showPanelFor(id, x) {
    var panel = panelFor[id]
    if (panel) showPanel(panel, x)
  }

  function switchPanelFrom(id, direction) {
    var configured = Config.bar.left.concat(Config.bar.center).concat(Config.bar.right)
    var ids = []
    for (var i = 0; i < configured.length; i++)
      if (panelFor[configured[i]] && ids.indexOf(configured[i]) < 0) ids.push(configured[i])
    for (var key in panelFor)
      if (ids.indexOf(key) < 0) ids.push(key)
    if (ids.length < 2) return
    var index = ids.indexOf(id)
    if (index < 0) return
    var next = (index + (direction < 0 ? -1 : 1) + ids.length) % ids.length
    showPanelFor(ids[next], -1)
  }

  // Which widget's panel is open, derived from panelFor so the id -> panel map
  // stays the only place ids appear. Empty when none is open.
  readonly property string activeWidgetId: {
    for (var id in panelFor)
      if (panelFor[id].opened) return id
    return ""
  }

  Variants {
    model: Quickshell.screens

    delegate: Bar {
      required property var modelData
      screen: modelData
      activeId: shell.activeWidgetId
      panelOpen: shell.activeWidgetId !== ""

      onWidgetActivated: function(id, x) { shell.showPanelFor(id, x) }
      onBarClicked: shell.closePanels()
    }
  }

  CalendarPanel { id: calendarPanel }
  WeatherPanel { id: weatherPanel }
  WorldClockPanel { id: worldClockPanel }
  BluetoothPanel {
    id: bluetoothPanel
    onSwitchPanelRequested: function(direction) { shell.switchPanelFrom("bluetooth", direction) }
  }
  Visualizer {}

  IpcHandler {
    target: "omashell"

    function toggleCalendar(): void { shell.showPanel(calendarPanel, -1) }
    function toggleWeather(): void { shell.showPanel(weatherPanel, -1) }
    function toggleWorldClock(): void { shell.showPanel(worldClockPanel, -1) }
    function toggleBluetooth(): void { shell.showPanel(bluetoothPanel, -1) }
    function closeAll(): void { shell.closePanels() }
  }
}
