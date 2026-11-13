pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: root

  property string location: ""
  property var place: null
  property var report: null
  property bool loading: false
  property bool failed: false
  property double updatedAtMs: 0

  readonly property var current: report && report.current ? report.current : null

  readonly property var countryNames: ({
    PK: "Pakistan", IN: "India", US: "United States", GB: "United Kingdom",
    CA: "Canada", AU: "Australia", DE: "Germany", FR: "France", NL: "Netherlands",
    AE: "United Arab Emirates", SA: "Saudi Arabia", SG: "Singapore", JP: "Japan",
    CN: "China", BR: "Brazil", ZA: "South Africa", TR: "Turkey", EG: "Egypt"
  })

  readonly property string locationName: {
    if (!place) return ""
    var country = String(place.country || "")
    if (country.length <= 2) country = root.countryNames[country] || country
    return place.name + (country !== "" ? ", " + country : "")
  }

  readonly property string tempNumber: current ? String(Math.round(Number(current.temperature_2m))) : ""
  readonly property string tempUnit: current ? "\u00B0C" : ""
  readonly property string feelsText: current ? String(Math.round(Number(current.apparent_temperature))) + "\u00B0C" : ""
  readonly property string windText: current ? String(Math.round(Number(current.wind_speed_10m))) + " km/h" : ""
  readonly property string humidityText: current ? String(current.relative_humidity_2m) + "%" : ""
  readonly property string glyph: current
    ? iconForCode(current.weather_code, Number(current.is_day) === 0)
    : "\uE33D"
  readonly property var forecast: buildForecast()

  readonly property var weekdays: ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]

  function iconForCode(code, night) {
    var c = parseInt(String(code || "0"), 10)
    if (c === 0) return night ? "\uE32B" : "\uE30D"
    if (c === 1 || c === 2) return night ? "\uE32E" : "\uE302"
    if (c === 3) return "\uE33D"
    if (c === 45 || c === 48) return "\uE313"
    if (c === 51 || c === 53 || c === 55 || c === 56 || c === 57 || c === 61) return "\uE308"
    if (c === 63 || c === 65 || c === 66 || c === 67 || c === 80 || c === 81 || c === 82) return "\uE318"
    if (c === 71 || c === 73 || c === 75 || c === 77 || c === 85 || c === 86) return "\uE31A"
    if (c === 95 || c === 96 || c === 99) return "\uE31D"
    return "\uE33D"
  }

  function dayName(dateText) {
    var d = new Date(String(dateText) + "T12:00:00")
    return isNaN(d.getTime()) ? "" : weekdays[d.getDay()].toUpperCase()
  }

  function buildForecast() {
    if (!report || !report.daily || !report.daily.time) return []
    var daily = report.daily
    var out = []
    for (var i = 0; i < Math.min(3, daily.time.length); i++) {
      out.push({
        label: dayName(daily.time[i]),
        glyph: iconForCode(daily.weather_code[i], false),
        high: daily.temperature_2m_max[i] !== undefined
          ? String(Math.round(Number(daily.temperature_2m_max[i]))) + "\u00B0"
          : "",
        low: daily.temperature_2m_min[i] !== undefined
          ? String(Math.round(Number(daily.temperature_2m_min[i]))) + "\u00B0"
          : ""
      })
    }
    return out
  }

  function fail() {
    loading = false
    failed = true
  }

  function startForecast() {
    if (!place) {
      fail()
      return
    }

    forecastProc.command = ["curl", "-fsS", "--max-time", "12",
      "https://api.open-meteo.com/v1/forecast"
        + "?latitude=" + place.latitude
        + "&longitude=" + place.longitude
        + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code,is_day"
        + "&daily=weather_code,temperature_2m_max,temperature_2m_min"
        + "&forecast_days=4&timezone=auto"]
    forecastProc.running = true
  }

  function refresh() {
    if (geocodeProc.running || ipLookupProc.running || forecastProc.running) return

    loading = true
    failed = false

    if (location === "") {
      ipLookupProc.running = true
      return
    }

    geocodeProc.command = ["curl", "-fsS", "--max-time", "10",
      "https://geocoding-api.open-meteo.com/v1/search"
        + "?name=" + encodeURIComponent(location)
        + "&count=1&language=en&format=json"]
    geocodeProc.running = true
  }

  function refreshIfStale() {
    if (!report || Date.now() - updatedAtMs > 600000) refresh()
  }

  property Process ipLookupProc: Process {
    id: ipLookupProc

    command: ["curl", "-fsS", "--max-time", "10", "https://ipinfo.io/json"]

    stdout: StdioCollector {
      waitForEnd: true

      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw === "") {
          root.fail()
          return
        }

        try {
          var parsed = JSON.parse(raw)
          var loc = String(parsed.loc || "").split(",")
          if (loc.length < 2) {
            root.fail()
            return
          }

          var latitude = Number(loc[0])
          var longitude = Number(loc[1])
          if (!isFinite(latitude) || !isFinite(longitude)) {
            root.fail()
            return
          }

          root.place = {
            name: String(parsed.city || parsed.region || "Unknown"),
            region: String(parsed.region || ""),
            country: String(parsed.country || ""),
            latitude: latitude,
            longitude: longitude
          }
          root.startForecast()
        } catch (e) {
          root.fail()
        }
      }
    }

    onExited: function(exitCode) {
      if (exitCode !== 0) root.fail()
    }
  }

  property Process geocodeProc: Process {
    id: geocodeProc

    stdout: StdioCollector {
      waitForEnd: true

      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw === "") {
          root.fail()
          return
        }

        try {
          var parsed = JSON.parse(raw)
          if (!parsed.results || parsed.results.length === 0) {
            root.fail()
            return
          }

          root.place = parsed.results[0]
          root.startForecast()
        } catch (e) {
          root.fail()
        }
      }
    }

    onExited: function(exitCode) {
      if (exitCode !== 0) root.fail()
    }
  }

  property Process forecastProc: Process {
    id: forecastProc

    stdout: StdioCollector {
      waitForEnd: true

      onStreamFinished: {
        var raw = String(text || "").trim()
        if (raw === "") {
          root.fail()
          return
        }

        try {
          root.report = JSON.parse(raw)
          root.loading = false
          root.failed = false
          root.updatedAtMs = Date.now()
        } catch (e) {
          root.fail()
        }
      }
    }

    onExited: function(exitCode) {
      if (exitCode !== 0) root.fail()
    }
  }

  property Timer refreshTimer: Timer {
    interval: 900000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.refresh()
}
