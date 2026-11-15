pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: root

  property string homeCity: ""
  property string homeZone: ""
  property var homePlace: null
  property var homeLocation: null
  property var cities: []
  property bool settingsReady: false
  property bool savePending: false
  readonly property string settingsScript: String(Qt.resolvedUrl("state.py")).replace("file://", "")

  function loadSettings() {
    if (!settingsLoad.running && !settingsSave.running) settingsLoad.running = true
  }
  function saveSettings() {
    if (!settingsReady) return
    if (settingsSave.running) { savePending = true; return }
    settingsSave.command = ["python3", settingsScript, "save", JSON.stringify({ cities: cities, here: homePlace })]
    settingsSave.running = true
  }
  function addCity(city) {
    if (!city || !city.zone || !city.label) return
    for (var i = 0; i < cities.length; i++)
      if (cities[i].zone === city.zone && cities[i].label.toLowerCase() === city.label.toLowerCase()) return
    cities = cities.concat([city])
    refreshOffsets()
    saveSettings()
  }
  function setPeople(index, names) {
    if (index < 0 || index >= cities.length) return
    var next = cities.slice()
    var city = Object.assign({}, next[index])
    city.people = names.split(",").map(function(name) { return name.trim() }).filter(function(name) { return name.length > 0 }).slice(0, 20)
    next[index] = city
    cities = next
    saveSettings()
  }
  function removeCity(index) {
    if (cities.length <= 1 || index < 0 || index >= cities.length) return
    var next = cities.slice(); next.splice(index, 1); cities = next
    refreshOffsets()
    saveSettings()
  }
  function setHome(city) {
    if (!city || city.zone !== homeZone) return
    homePlace = city
    homeLocation = city
    homeCity = city.label
    saveSettings()
  }
  property Process settingsLoad: Process {
    command: ["python3", root.settingsScript, "load"]
    stdout: StdioCollector { onStreamFinished: {
      try {
        var data = JSON.parse(text)
        root.homeZone = data.home.zone
        root.homeCity = data.home.label
        root.homePlace = data.here || null
        root.homeLocation = data.home
        root.cities = data.cities
        root.settingsReady = true
        root.refreshOffsets()
        if (data.firstRun) root.saveSettings()
      } catch (e) { console.warn("World clock settings:", e) }
    } }
    stderr: StdioCollector { onStreamFinished: if (text.trim()) console.warn(String(text).trim()) }
  }
  property Process settingsSave: Process {
    stderr: StdioCollector { onStreamFinished: if (text.trim()) console.warn(String(text).trim()) }
    onExited: function(code) {
      if (code !== 0) console.warn("World clock settings could not be saved")
      if (root.savePending) { root.savePending = false; root.saveSettings() }
    }
  }

  property bool offsetsPending: false
  property var offsets: ({})
  property var abbrs: ({})
  property int localOffsetMinutes: -new Date().getTimezoneOffset()
  property double nowMs: Date.now()

  readonly property var weekdaysShort: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  readonly property var monthsShort: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

  readonly property string localTime: timeAt(localOffsetMinutes)
  readonly property string caption: homeCity ? "It's " + localTime + " here in " + homeCity : "It's " + localTime + " here"

  readonly property var rows: {
    var out = []
    for (var i = 0; i < cities.length; i++) {
      out.push({
        label: cities[i].label,
        zone: cities[i].zone,
        offset: offsets[cities[i].zone],
        abbr: abbrs[cities[i].zone] || "",
        people: Array.isArray(cities[i].people) ? cities[i].people : [],
        home: cities[i].zone === homeZone
      })
    }
    return out
  }

  function pad2(value) {
    var n = Number(value)
    return (n < 10 ? "0" : "") + n
  }

  function parseOffset(text) {
    var m = /^([+-])(\d{2})(\d{2})$/.exec(String(text || "").trim())
    if (!m) return null
    var minutes = parseInt(m[2], 10) * 60 + parseInt(m[3], 10)
    return m[1] === "-" ? -minutes : minutes
  }

  function timeAt(offset) {
    if (offset === undefined || offset === null) return "--:--"
    var d = new Date(nowMs + offset * 60000)
    var hour = d.getUTCHours()
    return (hour % 12 || 12) + ":" + pad2(d.getUTCMinutes()) + (hour < 12 ? " AM" : " PM")
  }

  function dateAt(offset) {
    if (offset === undefined || offset === null) return ""
    var d = new Date(nowMs + offset * 60000)
    return weekdaysShort[d.getUTCDay()] + " " + monthsShort[d.getUTCMonth()] + " " + d.getUTCDate()
  }

  function dayNumber(offset) {
    var d = new Date(nowMs + offset * 60000)
    return Math.floor(Date.UTC(d.getUTCFullYear(), d.getUTCMonth(), d.getUTCDate()) / 86400000)
  }

  function dayLabel(offset) {
    if (offset === undefined || offset === null) return ""
    var delta = dayNumber(offset) - dayNumber(localOffsetMinutes)
    if (delta === 0) return ""
    if (delta === 1) return "Tomorrow"
    if (delta === -1) return "Yesterday"
    return (delta > 0 ? "+" : "") + delta + (Math.abs(delta) === 1 ? " day" : " days")
  }

  function greeting(offset) {
    if (offset === undefined || offset === null) return ""
    var hour = new Date(nowMs + offset * 60000).getUTCHours()
    if (hour < 5) return "Good night"
    if (hour < 12) return "Good morning"
    if (hour < 18) return "Good afternoon"
    return "Good evening"
  }

  function offsetLabel(offset) {
    if (offset === undefined || offset === null) return ""
    var diff = offset - localOffsetMinutes
    if (diff === 0) return ""
    var hours = Math.round(diff / 6) / 10
    return (diff > 0 ? "+" : "") + hours + "h"
  }

  function phaseFor(offset) {
    if (offset === undefined || offset === null) return "night"
    var h = new Date(nowMs + offset * 60000).getUTCHours()
    if (h < 6 || h >= 20) return "night"
    if (h < 8) return "dawn"
    if (h < 17) return "day"
    return "dusk"
  }

  function phaseFill(offset) {
    var phase = phaseFor(offset)
    if (phase === "day") return 0.10
    if (phase === "night") return 0.035
    return 0.07
  }

  function isLit(offset) {
    if (offset === undefined || offset === null) return false
    var d = new Date(nowMs + offset * 60000)
    var minutes = d.getUTCHours() * 60 + d.getUTCMinutes()
    return minutes >= 6 * 60 && minutes < 18 * 60
  }

  function progressAt(offset) {
    if (offset === undefined || offset === null) return 0
    var d = new Date(nowMs + offset * 60000)
    return (d.getUTCHours() * 60 + d.getUTCMinutes()) / 1440
  }

  function refreshOffsets() {
    if (probe.running) { offsetsPending = true; return }

    var ids = []
    for (var i = 0; i < cities.length; i++) ids.push(cities[i].zone)

    probe.command = ["bash", "-c",
      "if [ -z \"$TZDIR\" ] && [ -d /etc/zoneinfo ]; then TZDIR=/etc/zoneinfo; export TZDIR; fi; "
        + "printf 'LOCAL|'; date '+%z|%Z'; "
        + "for z in \"$@\"; do printf '%s|' \"$z\"; TZ=\"$z\" date '+%z|%Z'; done",
      "bash"].concat(ids)
    probe.running = true
  }

  property Process probe: Process {
    id: probe
    onExited: {
      if (root.offsetsPending) { root.offsetsPending = false; Qt.callLater(root.refreshOffsets) }
    }

    stdout: StdioCollector {
      waitForEnd: true

      onStreamFinished: {
        var lines = String(text || "").trim().split("\n")
        var nextOffsets = ({})
        var nextAbbrs = ({})

        for (var i = 0; i < lines.length; i++) {
          var fields = lines[i].split("|")
          if (fields.length < 3) continue

          var offset = root.parseOffset(fields[1])
          if (offset === null) continue

          var id = fields[0].trim()
          if (id === "LOCAL") {
            root.localOffsetMinutes = offset
          } else {
            nextOffsets[id] = offset
            nextAbbrs[id] = fields[2].trim()
          }
        }

        root.offsets = nextOffsets
        root.abbrs = nextAbbrs
      }
    }
  }

  property Timer tickTimer: Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.nowMs = Date.now()
  }

  property Timer offsetTimer: Timer {
    interval: 300000
    running: true
    repeat: true
    onTriggered: root.refreshOffsets()
  }

  Component.onCompleted: root.loadSettings()
}
