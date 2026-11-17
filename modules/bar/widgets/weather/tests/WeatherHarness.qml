import QtQuick
import Quickshell
import qs.modules.bar.widgets.weather

ShellRoot {
  Timer {
    interval: 50
    running: true
    repeat: true
    property int attempts: 0
    onTriggered: {
      attempts++
      if (WeatherService.loading && attempts < 120) return
      var expectedFailure = Quickshell.env("WEATHER_TEST_CASE") === "both-fail"
      var ok = expectedFailure
        ? WeatherService.failed && WeatherService.current === null
        : !WeatherService.failed && WeatherService.current !== null &&
          WeatherService.tempNumber === "25" && WeatherService.forecast.length === 1 &&
          WeatherService.forecast[0].high === "30°"
      console.log(ok ? "TEST PASS" : "TEST FAIL: unexpected weather state")
      Qt.exit(ok ? 0 : 1)
    }
  }
}
