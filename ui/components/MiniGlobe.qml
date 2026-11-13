import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import "MiniGlobe.js" as Geo

Item {
  id: root

  property real spin: 67.01
  property color color: Colors.foreground
  property bool bold: true
  property bool showMarker: true
  property real markerLat: 24.86
  property real markerLon: 67.01
  property color markerColor: Colors.accent
  property var land: []

  readonly property real radius: Math.min(width, height) / 2 - 1

  rotation: Geo.AXIAL_TILT

  FileView {
    path: String(Qt.resolvedUrl("../../assets/world.json")).replace("file://", "")
    printErrors: false

    onLoaded: {
      try {
        root.land = JSON.parse(text())
        canvas.requestPaint()
      } catch (e) {
      }
    }
  }

  onSpinChanged: canvas.requestPaint()
  onColorChanged: canvas.requestPaint()
  onLandChanged: canvas.requestPaint()
  onShowMarkerChanged: canvas.requestPaint()

  Canvas {
    id: canvas
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative

    function strokePath(ctx, pts) {
      var segs = Geo.visibleSegments(pts, root.spin, 0, root.radius)
      for (var i = 0; i < segs.length; i++) {
        ctx.moveTo(segs[i][0].x, segs[i][0].y)
        for (var j = 1; j < segs[i].length; j++) ctx.lineTo(segs[i][j].x, segs[i][j].y)
      }
    }

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      ctx.translate(width / 2, height / 2)

      var r = root.radius
      if (r <= 0) return

      var c = root.color
      var lat
      var lon
      var pts
      var i

      ctx.beginPath()
      ctx.arc(0, 0, r, 0, Math.PI * 2)
      ctx.fillStyle = Geo.mix(Colors.background, c, 0.16)
      ctx.fill()

      ctx.save()
      ctx.beginPath()
      ctx.arc(0, 0, r, 0, Math.PI * 2)
      ctx.clip()

      ctx.beginPath()
      for (lon = -90; lon < 90; lon += 90) {
        pts = []
        for (lat = -90; lat <= 90; lat += 6) pts.push([lat, lon])
        strokePath(ctx, pts)
      }

      pts = []
      for (lon = -180; lon <= 180; lon += 6) pts.push([0, lon])
      strokePath(ctx, pts)

      ctx.lineWidth = Math.max(1, r * 0.055)
      ctx.strokeStyle = Geo.alpha(c, 0.42)
      ctx.stroke()

      if (root.land.length > 0) {
        ctx.beginPath()
        for (i = 0; i < root.land.length; i++) {
          var ring = root.land[i]
          if (ring.length < 40) continue
          var poly = Geo.clipRingToDisc(ring, root.spin, 0, root.radius)
          if (poly.length < 3) continue
          ctx.moveTo(poly[0].x, poly[0].y)
          for (var q = 1; q < poly.length; q++) ctx.lineTo(poly[q].x, poly[q].y)
          ctx.closePath()
        }
        ctx.fillStyle = Geo.alpha(c, 1.0)
        ctx.fill()
      }

      if (root.showMarker) {
        var mp = Geo.project(root.markerLat, root.markerLon, root.spin, 0, r)
        if (mp.visible) {
          var mr = Math.max(1.6, r * 0.13)
          ctx.beginPath()
          ctx.arc(mp.x, mp.y, mr, 0, Math.PI * 2)
          ctx.fillStyle = root.markerColor
          ctx.fill()

          ctx.beginPath()
          ctx.arc(mp.x, mp.y, mr * 1.9, 0, Math.PI * 2)
          ctx.lineWidth = Math.max(1, r * 0.045)
          ctx.strokeStyle = Geo.alpha(root.markerColor, 0.65)
          ctx.stroke()
        }
      }

      ctx.restore()

      ctx.beginPath()
      ctx.arc(0, 0, r, 0, Math.PI * 2)
      ctx.lineWidth = Math.max(1, r * 0.095)
      ctx.strokeStyle = Geo.alpha(c, 1.0)
      ctx.stroke()
    }
  }
}
