import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "MiniGlobe.js" as Geo

Column {
  id: root
  spacing: 5
  property var cities: []
  property var placeCache: ({})
  property string wantedQuery: ""
  property bool addToClock: false
  property bool excludeTracked: false
  property alias searchText: search.text
  signal cityAdded()
  readonly property var displayCities: {
    if (!selected) return cities
    for (var i = 0; i < cities.length; i++)
      if (sameCity(cities[i], selected)) return cities
    return cities.concat([selected])
  }
  property var land: []
  property var searchOffsets: ({})
  property var selected: null
  property real spin: WorldClockService.homeLocation && WorldClockService.homeLocation.lon !== undefined ? WorldClockService.homeLocation.lon : 0
  property real viewLat: 20
  property bool searching: false
  property string selectedTime: ""
  property var selectedOffset: null
  property bool offsetFromUtc: false
  property int searchIndex: 0
  readonly property color sunlight: "#e5c736"
  readonly property var majorZones: [
    "Pacific/Pago_Pago", "Pacific/Honolulu", "America/Anchorage", "America/Los_Angeles",
    "America/Vancouver", "America/Denver", "America/Phoenix", "America/Mexico_City",
    "America/Chicago", "America/New_York", "America/Toronto", "America/Bogota",
    "America/Lima", "America/Halifax", "America/Caracas", "America/Santiago",
    "America/Sao_Paulo", "America/Argentina/Buenos_Aires", "Atlantic/Reykjavik",
    "Europe/London", "Europe/Lisbon", "Europe/Paris", "Europe/Berlin", "Europe/Madrid",
    "Africa/Lagos", "Europe/Rome", "Africa/Cairo", "Europe/Athens", "Africa/Johannesburg",
    "Europe/Kyiv", "Europe/Moscow", "Europe/Istanbul", "Africa/Nairobi", "Asia/Riyadh",
    "Asia/Tehran", "Asia/Dubai", "Asia/Kabul", "Asia/Karachi", "Asia/Kolkata",
    "Asia/Kathmandu", "Asia/Dhaka", "Asia/Almaty", "Asia/Yangon", "Asia/Bangkok",
    "Asia/Jakarta", "Asia/Singapore", "Asia/Shanghai", "Asia/Hong_Kong", "Australia/Perth",
    "Asia/Seoul", "Asia/Tokyo", "Australia/Darwin", "Australia/Adelaide", "Australia/Sydney",
    "Australia/Brisbane", "Pacific/Noumea", "Pacific/Auckland", "Pacific/Fiji", "Pacific/Apia"
  ]
  property real lastX: 0
  property real lastY: 0
  property bool dragged: false
  property real velocity: 0
  signal dismissRequested()
  readonly property var filtered: {
    var term = search.text.trim().toLowerCase()
    var starts = [], contains = []
    for (var i = 0; i < cities.length; i++) {
      var city = cities[i], label = city.label.toLowerCase(), zone = city.zone.toLowerCase()
      if (excludeTracked && WorldClockService.cities.some(function(row) { return sameCity(row, city) })) continue
      if (!term || label.indexOf(term) === 0) starts.push(city)
      else if (label.indexOf(term) >= 0 || zone.indexOf(term) >= 0) contains.push(city)
    }
    var matches = starts.concat(contains).slice(0, 5)
    var places = placeCache[term] || []
    for (var j = 0; j < places.length && j < 2; j++) {
      var duplicate = excludeTracked && WorldClockService.cities.some(function(row) { return sameCity(row, places[j]) })
      for (var k = 0; k < matches.length; k++)
        if (sameCity(matches[k], places[j])) {
          if (!hasCoordinates(matches[k])) matches[k] = places[j]
          duplicate = true
          break
        }
      if (!duplicate) matches.push(places[j])
    }
    return matches
  }

  function sameCity(a, b) { return a && b && a.zone === b.zone && String(a.label).toLowerCase() === String(b.label).toLowerCase() }
  function hasCoordinates(city) { return city && city.lat !== undefined && city.lon !== undefined && city.lat !== null && city.lon !== null && isFinite(Number(city.lat)) && isFinite(Number(city.lon)) }
  function shownCity(city) {
    if (!hasCoordinates(city)) return false
    if (sameCity(root.selected, city)) return true
    for (var i = 0; i < WorldClockService.cities.length; i++)
      if (city.zone === WorldClockService.cities[i].zone) return true
    return root.majorZones.indexOf(city.zone) >= 0
  }
  function daylight(city) {
    if (!hasCoordinates(city)) return selectedOffset !== null && WorldClockService.isLit(selectedOffset)
    var now = new Date()
    var days = (now.getTime() - Date.UTC(now.getUTCFullYear(), 0, 0)) / 86400000
    var decl = 23.44 * Math.sin(2 * Math.PI * (284 + days) / 365.24) * Geo.DEG
    var sunLon = (180 - (now.getUTCHours() * 60 + now.getUTCMinutes()) / 4) * Geo.DEG
    var lat = city.lat * Geo.DEG
    return Math.sin(lat) * Math.sin(decl) + Math.cos(lat) * Math.cos(decl) * Math.cos(city.lon * Geo.DEG - sunLon) > 0
  }
  function offsetText() {
    if (selectedOffset === null) return ""
    var value = selectedOffset - (offsetFromUtc ? 0 : WorldClockService.localOffsetMinutes)
    if (!value) return offsetFromUtc ? "UTC" : ""
    var hours = Math.floor(Math.abs(value) / 60)
    var minutes = Math.abs(value) % 60
    return (value < 0 ? "−" : "+") + hours + (minutes ? ":" + (minutes < 10 ? "0" : "") + minutes : "") + "h"
  }
  function choose(city) {
    if (!city) return
    selected = city
    if (addToClock) {
      WorldClockService.addCity(city)
      addToClock = false
      searching = false
      search.text = ""
      cityAdded()
      return
    }
    if (city.zone === WorldClockService.homeZone && city.label !== WorldClockService.homeCity) WorldClockService.setHome(city)
    if (hasCoordinates(city)) {
      spinAnimation.stop()
      var target = city.lon
      while (target - spin > 180) target -= 360
      while (target - spin < -180) target += 360
      spinAnimation.from = spin
      spinAnimation.to = target
      spinAnimation.start()
      latAnimation.from = viewLat
      latAnimation.to = Math.max(-70, Math.min(70, city.lat))
      latAnimation.restart()
    }
    searching = false
    search.text = ""
    selectedTime = ""
    selectedOffset = null
    clockProbe.command = ["env", "TZ=" + city.zone, "date", "+%-I:%M %p|%z"]
    if (clockProbe.running) clockProbe.running = false
    clockProbe.running = true
    canvas.requestPaint()
  }
  function resetSearch() {
    searching = false
    addToClock = false
    excludeTracked = false
    search.text = ""
    wantedQuery = ""
    placeDelay.stop()
    searchOffsetDelay.stop()
  }
  function beginSearch() { searching = true; searchIndex = 0; searchOffsetDelay.restart(); Qt.callLater(function() { if (root.searching && root.visible) search.forceActiveFocus() }) }
  function beginInlineSearch() {
    excludeTracked = true
    searching = true
    searchIndex = 0
    search.text = ""
    if (cities.length === 0 && !cityProbe.running) cityProbe.running = true
    searchOffsetDelay.restart()
  }
  function requestPlaces(value) {
    var query = String(value || "").trim().replace(/\s+/g, " ").toLowerCase()
    wantedQuery = query.length >= 3 ? query : ""
    if (wantedQuery && placeCache[wantedQuery] === undefined) placeDelay.restart()
  }
  function searchOffset(zone) {
    var offset = searchOffsets[zone]
    if (offset === undefined || offset === null) return ""
    if (!offset) return "UTC"
    var n = Math.abs(offset)
    return "UTC" + (offset < 0 ? "−" : "+") + Math.floor(n / 60) + (n % 60 ? ":" + (n % 60 < 10 ? "0" : "") + n % 60 : "")
  }
  function leaveSearch() { searching = false; search.text = ""; if (addToClock) { addToClock = false; cityAdded() } else root.forceActiveFocus() }
  Keys.onEscapePressed: { if (searching) leaveSearch(); else dismissRequested() }
  function paint() { canvas.requestPaint() }
  onSpinChanged: paint()
  onViewLatChanged: paint()
  onLandChanged: paint()
  onCitiesChanged: paint()
  onSelectedChanged: paint()
  onFilteredChanged: if (searching) searchOffsetDelay.restart()
  onVisibleChanged: {
    if (visible) {
      if (cities.length === 0 && !cityProbe.running) cityProbe.running = true
      Qt.callLater(function() { if (root.visible) root.forceActiveFocus() })
    } else { searching = false; search.text = "" }
  }
  Component.onCompleted: if (visible && cities.length === 0 && !cityProbe.running) cityProbe.running = true

  NumberAnimation { id: spinAnimation; target: root; property: "spin"; duration: 650; easing.type: Easing.OutCubic }
  NumberAnimation { id: latAnimation; target: root; property: "viewLat"; duration: 650; easing.type: Easing.OutCubic }
  Timer {
    interval: 16; repeat: true; running: Math.abs(root.velocity) > 0.02 && !drag.pressed
    onTriggered: { root.spin += root.velocity; root.velocity *= 0.95 }
  }
  Timer {
    id: placeDelay
    interval: 350
    onTriggered: {
      if (!root.wantedQuery || root.placeCache[root.wantedQuery] !== undefined) return
      if (placeProbe.running) { restart(); return }
      placeProbe.query = root.wantedQuery
      placeProbe.command = ["curl", "-fsS", "--max-time", "8", "https://geocoding-api.open-meteo.com/v1/search?count=10&language=en&format=json&name=" + encodeURIComponent(placeProbe.query)]
      placeProbe.running = true
    }
  }
  Process {
    id: placeProbe
    property string query: ""
    stdout: StdioCollector { onStreamFinished: {
      var found = []
      try {
        var payload = JSON.parse(text), items = Array.isArray(payload.results) ? payload.results.slice(0, 10) : []
        for (var i = 0; i < items.length; i++) {
          var item = items[i], lat = Number(item.latitude), lon = Number(item.longitude)
          if (!item.name || typeof item.timezone !== "string" || !/^[A-Za-z0-9_+.-]+(?:\/[A-Za-z0-9_+.-]+)+$/.test(item.timezone) || !isFinite(lat) || !isFinite(lon) || Math.abs(lat) > 90 || Math.abs(lon) > 180) continue
          var region = [item.admin1 || "", item.country_code || item.country || ""].filter(function(s) { return s && s !== item.name }).join(", ")
          found.push({ label: String(item.name).slice(0, 100), zone: item.timezone, lat: lat, lon: lon, region: region })
        }
      } catch (e) { }
      var next = Object.assign({}, root.placeCache); next[placeProbe.query] = found; root.placeCache = next
    } }
    onExited: function(code) {
      if (code !== 0 && root.placeCache[query] === undefined) {
        var next = Object.assign({}, root.placeCache); next[query] = []; root.placeCache = next
      }
      if (root.wantedQuery && root.placeCache[root.wantedQuery] === undefined) placeDelay.restart()
    }
  }
  Timer {
    id: searchOffsetDelay
    interval: 120
    onTriggered: {
      if (offsetProbe.running) { restart(); return }
      var zones = root.filtered.map(function(city) { return city.zone })
      if (!zones.length) return
      offsetProbe.command = ["bash", "-c", "for z in \"$@\"; do printf '%s|' \"$z\"; TZ=\"$z\" date +%z; done", "bash"].concat(zones)
      offsetProbe.running = true
    }
  }
  Process {
    id: offsetProbe
    stdout: StdioCollector { onStreamFinished: {
      var next = Object.assign({}, root.searchOffsets)
      String(text).trim().split("\n").forEach(function(line) {
        var parts = line.split("|")
        if (parts.length === 2) next[parts[0]] = WorldClockService.parseOffset(parts[1])
      })
      root.searchOffsets = next
    } }
  }
  Timer { interval: 60000; repeat: true; running: root.visible && root.selected !== null; onTriggered: {
      if (!clockProbe.running) { clockProbe.command = ["env", "TZ=" + root.selected.zone, "date", "+%-I:%M %p|%z"];  clockProbe.running = true }
      canvas.requestPaint()
  } }
  FileView {
    path: String(Qt.resolvedUrl("../../../../assets/world.json")).replace("file://", "")
    printErrors: false
    onLoaded: { try { root.land = JSON.parse(text()) } catch (e) { console.warn("World map:", e) } }
  }
  Process {
    id: cityProbe
    command: ["python3", String(Qt.resolvedUrl("cities.py")).replace("file://", "")]
    stdout: StdioCollector { onStreamFinished: {
      try {
        root.cities = JSON.parse(text).sort(function(a, b) { return a.label.localeCompare(b.label) })
        var home = WorldClockService.homeLocation
        if (!root.excludeTracked && home && home.lat !== undefined) root.choose(home)
      } catch (e) { console.warn("Timezone locations:", e) }
    } }
  }
  Connections {
    target: WorldClockService
    function onHomeLocationChanged() {
      var home = WorldClockService.homeLocation
      if (!root.excludeTracked && !root.selected && home && home.lat !== undefined) root.choose(home)
    }
  }
  Process {
    id: clockProbe
    stdout: StdioCollector { onStreamFinished: {
      var fields = String(text).trim().split("|")
      root.selectedTime = fields[0] || ""
      root.selectedOffset = fields.length > 1 ? WorldClockService.parseOffset(fields[1]) : null
    } }
  }

  Item {
    id: globe
    width: root.width - 8
    height: width
    anchors.horizontalCenter: parent.horizontalCenter
    z: root.searching ? 1 : 0
    Canvas {
      id: canvas
      anchors.fill: parent
      renderStrategy: Canvas.Cooperative
      onPaint: {
        var ctx = getContext("2d")
        ctx.reset()
        var r = width / 2 - 3
        ctx.translate(width / 2, height / 2)
        ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI)
        ctx.fillStyle = Geo.mix(Colors.background, Colors.foreground, 0.06); ctx.fill()
        ctx.save(); ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI); ctx.clip()
        function line(points) {
          var segs = Geo.visibleSegments(points, root.spin, root.viewLat, r)
          for (var i = 0; i < segs.length; ++i) {
            ctx.moveTo(segs[i][0].x, segs[i][0].y)
            for (var j = 1; j < segs[i].length; ++j) ctx.lineTo(segs[i][j].x, segs[i][j].y)
          }
        }
        ctx.beginPath()
        for (var lon = -180; lon < 180; lon += 30) {
          var a = []
          for (var lat = -90; lat <= 90; lat += 3) a.push([lat, lon])
          line(a)
        }
        for (var lat2 = -60; lat2 <= 60; lat2 += 30) {
          var b = []
          for (var lon2 = -180; lon2 <= 180; lon2 += 3) b.push([lat2, lon2])
          line(b)
        }
        ctx.strokeStyle = Geo.alpha(Colors.foreground, 0.09); ctx.lineWidth = 1; ctx.stroke()
        ctx.beginPath()
        var landPolygons = []
        for (var k = 0; k < root.land.length; ++k) {
          var polygon = Geo.clipRingToDisc(root.land[k], root.spin, root.viewLat, r)
          if (polygon.length < 3) continue
          landPolygons.push(polygon)
          ctx.moveTo(polygon[0].x, polygon[0].y)
          for (var n = 1; n < polygon.length; ++n) ctx.lineTo(polygon[n].x, polygon[n].y)
          ctx.closePath()
        }
        ctx.fillStyle = Geo.alpha(Colors.foreground, 0.9); ctx.fill()
        var now = new Date()
        var days = (now.getTime() - Date.UTC(now.getUTCFullYear(), 0, 0)) / 86400000
        var decl = 23.44 * Math.sin(2 * Math.PI * (284 + days) / 365.24) * Math.PI / 180
        var sunLon = 180 - (now.getUTCHours() * 60 + now.getUTCMinutes()) / 4
        var boundary = []
        for (var t = 0; t <= 360; t += 2) {
          var angle = t * Math.PI / 180
          var x = -Math.sin(decl) * Math.cos(angle)
          var y = Math.sin(angle)
          var z = Math.cos(decl) * Math.cos(angle)
          boundary.push([Math.asin(z) / Geo.DEG, sunLon + Math.atan2(y, x) / Geo.DEG])
        }
        ctx.beginPath(); line(boundary); ctx.strokeStyle = Geo.alpha(root.sunlight, 0.6); ctx.lineWidth = 1; ctx.stroke()
        for (var c = 0; c < root.displayCities.length; ++c) {
          var city = root.displayCities[c]
          if (!root.shownCity(city)) continue
          var p = Geo.project(city.lat, city.lon, root.spin, root.viewLat, r)
          if (!p.visible) continue
          var active = root.sameCity(root.selected, city)
          ctx.beginPath(); ctx.arc(p.x, p.y, active ? 4 : 2.6, 0, 2 * Math.PI)
          ctx.fillStyle = root.daylight(city) ? root.sunlight : Colors.background
          ctx.fill(); ctx.lineWidth = 1.5; ctx.strokeStyle = root.daylight(city) ? Colors.background : Colors.foreground; ctx.stroke()
          if (active) { ctx.beginPath(); ctx.arc(p.x, p.y, 8, 0, 2 * Math.PI); ctx.strokeStyle = root.sunlight; ctx.lineWidth = 1; ctx.stroke() }
        }
        if (!drag.pressed && Math.abs(root.velocity) < 0.05 && !spinAnimation.running) {
          var occupied = []
          ctx.font = "10px monospace"
          ctx.textBaseline = "middle"
          for (var m = 0; m < root.displayCities.length; m++) {
            var labelCity = root.displayCities[m]
            if (!root.shownCity(labelCity)) continue
            var lp = Geo.project(labelCity.lat, labelCity.lon, root.spin, root.viewLat, r)
            if (!lp.visible || lp.cosc < 0.15) continue
            var lx = lp.x + 6, ly = lp.y, labelWidth = ctx.measureText(labelCity.label).width
            if (lx + labelWidth > r - 3) lx = lp.x - labelWidth - 6
            var collision = false
            for (var h = 0; h < occupied.length; h++) {
              var box = occupied[h]
              if (lx < box.x + box.w + 3 && lx + labelWidth + 3 > box.x && Math.abs(ly - box.y) < 12) { collision = true; break }
            }
            if (collision) continue
            occupied.push({x: lx, y: ly, w: labelWidth})
            var onLand = false
            for (var polyIndex = 0; polyIndex < landPolygons.length; polyIndex++) {
              var ring = landPolygons[polyIndex], inside = false
              for (var a = 0, b = ring.length - 1; a < ring.length; b = a++) {
                if ((ring[a].y > ly) !== (ring[b].y > ly) && lx < (ring[b].x - ring[a].x) * (ly - ring[a].y) / (ring[b].y - ring[a].y) + ring[a].x) inside = !inside
              }
              if (inside) { onLand = true; break }
            }
            ctx.fillStyle = onLand ? Geo.alpha(Colors.background, 0.9) : Geo.alpha(Colors.foreground, 0.75)
            ctx.fillText(labelCity.label, lx, ly)
          }
        }
        ctx.restore(); ctx.beginPath(); ctx.arc(0, 0, r, 0, 2 * Math.PI)
        ctx.lineWidth = 1.5; ctx.strokeStyle = Geo.alpha(Colors.foreground, 0.25); ctx.stroke()
      }
    }
    MouseArea {
      id: drag
      anchors.fill: parent
      cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
      onPressed: function(mouse) { root.velocity = 0; root.dragged = false; root.lastX = mouse.x; root.lastY = mouse.y; spinAnimation.stop(); latAnimation.stop() }
      onPositionChanged: function(mouse) {
        if (!pressed) return
        var dx = mouse.x - root.lastX, dy = mouse.y - root.lastY
        if (Math.abs(mouse.x - pressX) + Math.abs(mouse.y - pressY) > 4) root.dragged = true
        if (root.dragged) { root.spin -= dx * 0.45; root.viewLat = Math.max(-80, Math.min(80, root.viewLat + dy * 0.35)); root.velocity = -dx * 0.45 }
        root.lastX = mouse.x; root.lastY = mouse.y
      }
      property real pressX: 0
      property real pressY: 0
      onPressedChanged: if (pressed) { pressX = mouseX; pressY = mouseY }
      onClicked: function(mouse) {
        if (root.dragged) return
        var r = width / 2 - 3, best = null, distance = 14
        for (var i = 0; i < root.displayCities.length; ++i) {
          if (!root.shownCity(root.displayCities[i])) continue
          var p = Geo.project(root.displayCities[i].lat, root.displayCities[i].lon, root.spin, root.viewLat, r)
          if (!p.visible) continue
          var d = Math.sqrt(Math.pow(mouse.x - width / 2 - p.x, 2) + Math.pow(mouse.y - height / 2 - p.y, 2))
          if (d < distance) { distance = d; best = root.displayCities[i] }
        }
        if (best) root.choose(best)
        else root.selected = null
      }
    }
  }
  Column {
    width: parent.width
    height: 28
    spacing: 1
    visible: true
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 7
      visible: root.selected !== null
      Row {
        spacing: 4
        Rectangle {
          anchors.verticalCenter: parent.verticalCenter
          width: 8; height: 8; radius: 4
          color: root.selected && root.daylight(root.selected) ? root.sunlight : "transparent"
          border.width: root.selected && root.daylight(root.selected) ? 0 : 1
          border.color: Colors.foreground
        }
        Text {
          text: root.selected ? root.selected.label : ""
          color: Colors.foreground; font.family: Constants.fontFamily; font.pixelSize: Constants.fontCaption; font.weight: Font.DemiBold
        }
      }
      Text {
        text: root.selectedTime
        color: Qt.darker(Colors.foreground, 1.55); font.family: Constants.fontFamily; font.pixelSize: Constants.fontCaption
      }
      Text {
        visible: root.selected !== null && (root.selected.zone === WorldClockService.homeZone || WorldClockService.cities.some(function(c) { return c.zone === root.selected.zone }))
        text: root.selected && root.selected.zone === WorldClockService.homeZone ? "home" : "tracked"
        color: Colors.accent; font.family: Constants.fontFamily; font.pixelSize: Constants.fontCaption
      }
    }
    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 6
      visible: root.selected !== null
      Text { text: root.selected ? root.selected.zone : ""; color: Qt.darker(Colors.foreground, 2.1); font.family: Constants.fontFamily; font.pixelSize: Constants.fontCaption }
      Text { text: root.offsetText(); color: Qt.darker(Colors.foreground, 1.55); font.family: Constants.fontFamily; font.pixelSize: Constants.fontCaption }
      HoverHandler { cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: root.offsetFromUtc = !root.offsetFromUtc }
    }
  }
  Rectangle {
    width: parent.width; height: 36; color: "transparent"; border.width: 1; border.color: Colors.darkForeground
    TextInput {
      id: search
      anchors.fill: parent; anchors.margins: 8
      color: Colors.foreground; font.family: Constants.fontFamily; font.pixelSize: Constants.fontBodySmall
      visible: root.searching; clip: true
      onTextChanged: { root.searchIndex = 0; root.requestPlaces(text) }
      Keys.onEscapePressed: root.leaveSearch()
      Keys.onDownPressed: { root.searchIndex = Math.min(root.filtered.length - 1, root.searchIndex + 1); results.positionViewAtIndex(root.searchIndex, ListView.Contain) }
      Keys.onUpPressed: { root.searchIndex = Math.max(0, root.searchIndex - 1); results.positionViewAtIndex(root.searchIndex, ListView.Contain) }
      Keys.onReturnPressed: if (root.filtered.length) { root.choose(root.filtered[Math.max(0, root.searchIndex)]); root.forceActiveFocus() }
      Keys.onEnterPressed: if (root.filtered.length) { root.choose(root.filtered[Math.max(0, root.searchIndex)]); root.forceActiveFocus() }
      Text { anchors.verticalCenter: parent.verticalCenter; visible: search.text.length === 0; text: "Search cities..."; color: Colors.darkForeground; font: search.font }
    }
    Text { anchors.centerIn: parent; visible: !root.searching; text: "Jump to a city"; color: Colors.foreground; font.family: Constants.fontFamily; font.pixelSize: Constants.fontBodySmall }
    MouseArea { anchors.fill: parent; enabled: !root.searching; onClicked: root.beginSearch() }
  }
  Rectangle {
    parent: globe
    x: (globe.width - width) / 2
    y: globe.height + 28 - height
    width: root.width
    height: root.searching ? Math.max(34, Math.min(160, results.count * 30 + 8)) : 0
    visible: root.searching
    color: Colors.background
    radius: Constants.cornerRadius
    ListView {
      id: results
      anchors.fill: parent; anchors.margins: 4
      clip: true; model: root.filtered
      Text {
        anchors.centerIn: parent
        visible: results.count === 0
        text: !root.cities.length ? "Loading cities..."
          : (root.wantedQuery && root.placeCache[root.wantedQuery] === undefined ? "Searching places..." : "No matches")
        color: Colors.darkForeground; font.family: Constants.fontFamily; font.pixelSize: Constants.fontCaption
      }
      delegate: Rectangle {
        required property var modelData
        required property int index
        width: ListView.view.width; height: 30; radius: Constants.cornerRadius
        color: index === root.searchIndex ? Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.08) : "transparent"
        Text { anchors.verticalCenter: parent.verticalCenter; anchors.left: parent.left; anchors.leftMargin: 10; anchors.right: zoneText.left; anchors.rightMargin: 6; elide: Text.ElideRight; text: modelData.label + (modelData.region ? "  " + modelData.region : ""); color: Colors.foreground; font.family: Constants.fontFamily; font.pixelSize: Constants.fontBodySmall }
        Text { id: zoneText; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData.zone + (root.searchOffset(modelData.zone) ? "  " + root.searchOffset(modelData.zone) : ""); color: Colors.darkForeground; font.family: Constants.fontFamily; font.pixelSize: Constants.fontCaption }
        MouseArea { id: resultMouse; anchors.fill: parent; hoverEnabled: true; onPositionChanged: root.searchIndex = index; onClicked: { root.choose(modelData); root.forceActiveFocus() } }
      }
    }
  }
}
