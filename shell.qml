import Quickshell
import Quickshell.Io
import qs.modules.bar
import qs.modules.bar.widgets.clock
import qs.modules.bar.widgets.weather
import qs.modules.bar.widgets.worldclock

ShellRoot {
  id: shell

  // The only place that maps a bar widget id to a popup. Keys match the ids in
  // config/shell.json and WidgetRegistry.
  readonly property var popupFor: ({
    clock: calendar,
    weather: weather,
    worldclock: worldClock
  })

  function showPopup(target, x) {
    if (target !== calendar) calendar.close()
    if (target !== weather) weather.close()
    if (target !== worldClock) worldClock.close()
    target.anchorX = x
    target.toggle()
  }

  // Unknown id (no popup) is a no-op, not an error.
  function showPopupFor(id, x) {
    var popup = popupFor[id]
    if (popup) showPopup(popup, x)
  }

  // Which widget's popup is open, derived from popupFor so the id -> popup map
  // stays the only place ids appear. Empty when none is open.
  readonly property string activeWidgetId: {
    for (var id in popupFor)
      if (popupFor[id].opened) return id
    return ""
  }

  Variants {
    model: Quickshell.screens

    delegate: Bar {
      required property var modelData
      screen: modelData
      activeId: shell.activeWidgetId

      onWidgetActivated: function(id, x) { shell.showPopupFor(id, x) }
    }
  }

  CalendarPopup { id: calendar }
  WeatherPopup { id: weather }
  WorldClockPopup { id: worldClock }

  IpcHandler {
    target: "omashell"

    function toggleCalendar(): void { shell.showPopup(calendar, -1) }
    function toggleWeather(): void { shell.showPopup(weather, -1) }
    function toggleWorldClock(): void { shell.showPopup(worldClock, -1) }
    function closeAll(): void { calendar.close(); weather.close(); worldClock.close() }
  }
}
