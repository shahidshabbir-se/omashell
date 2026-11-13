import Quickshell
import Quickshell.Io
import qs.ui.panels.bar
import qs.ui.popups

ShellRoot {
  id: shell

  function showPopup(target, x) {
    if (target !== calendar) calendar.close()
    if (target !== weather) weather.close()
    if (target !== worldClock) worldClock.close()
    target.anchorX = x
    target.toggle()
  }

  Variants {
    model: Quickshell.screens

    delegate: Bar {
      required property var modelData
      screen: modelData

      onCalendarToggleRequested: function(x) { shell.showPopup(calendar, x) }
      onWeatherToggleRequested: function(x) { shell.showPopup(weather, x) }
      onWorldClockToggleRequested: function(x) { shell.showPopup(worldClock, x) }
    }
  }

  Calendar { id: calendar }
  Weather { id: weather }
  WorldClock { id: worldClock }

  IpcHandler {
    target: "omashell"

    function toggleCalendar(): void { shell.showPopup(calendar, -1) }
    function toggleWeather(): void { shell.showPopup(weather, -1) }
    function toggleWorldClock(): void { shell.showPopup(worldClock, -1) }
    function closeAll(): void { calendar.close(); weather.close(); worldClock.close() }
  }
}
