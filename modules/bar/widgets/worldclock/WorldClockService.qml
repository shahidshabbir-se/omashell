pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
  id: root

  property string homeCity: "Karachi"
  property string homeZone: "Asia/Karachi"

  readonly property var cities: [
    { label: homeCity, zone: homeZone },
    { label: "Los Angeles", zone: "America/Los_Angeles" },
    { label: "Paris", zone: "Europe/Paris" },
    { label: "Tokyo", zone: "Asia/Tokyo" },
    { label: "New York", zone: "America/New_York" },
    { label: "Sydney", zone: "Australia/Sydney" }
  ]

  property var offsets: ({})
  property var abbrs: ({})
  property int localOffsetMinutes: -new Date().getTimezoneOffset()
  property double nowMs: Date.now()

  readonly property var weekdaysShort: ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
  readonly property var monthsShort: ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

  readonly property string localTime: timeAt(localOffsetMinutes)
  readonly property string caption: "It's " + localTime + " here in " + homeCity

  readonly property var rows: {
    var out = []
    for (var i = 0; i < cities.length; i++) {
      out.push({
        label: cities[i].label,
        zone: cities[i].zone,
        offset: offsets[cities[i].zone],
        abbr: abbrs[cities[i].zone] || "",
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
    return pad2(d.getUTCHours()) + ":" + pad2(d.getUTCMinutes())
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
    if (probe.running) return

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

  Component.onCompleted: root.refreshOffsets()
}
