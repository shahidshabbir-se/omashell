import QtQuick
import qs.config

Item {
  id: root

  property string text: ""
  property real rise: 6
  property int pixelSize: Constants.fontCaption
  property string fontFamily: Constants.fontFamily
  property color color: Colors.foreground

  FontMetrics {
    id: metrics
    font.family: root.fontFamily
    font.pixelSize: root.pixelSize
  }

  readonly property var glyphs: text.split("")

  function arcLayout(widths, rise) {
    var chars = []
    var total = 0
    var i
    for (i = 0; i < widths.length; i++) total += widths[i]

    if (total <= 0 || rise <= 0) {
      var x = 0
      for (i = 0; i < widths.length; i++) {
        chars.push({ x: x, y: 0, rotation: 0 })
        x += widths[i]
      }
      return { width: total, height: 0, chars: chars }
    }

    var sag = Math.min(rise, total / 4)
    var radius = (total * total) / (8 * sag)
    var halfAngle = total / (2 * radius)
    var maxDrop = radius * (1 - Math.cos(halfAngle))
    var chordWidth = 2 * radius * Math.sin(halfAngle)

    var travelled = 0
    var left = 0
    var right = chordWidth

    for (i = 0; i < widths.length; i++) {
      var w = widths[i]
      var a = (travelled + w / 2 - total / 2) / radius
      var drop = radius * (1 - Math.cos(a))
      var px = chordWidth / 2 + radius * Math.sin(a) - w / 2
      chars.push({ x: px, y: drop, rotation: a * 180 / Math.PI })
      left = Math.min(left, px)
      right = Math.max(right, px + w)
      travelled += w
    }

    for (i = 0; i < chars.length; i++) chars[i].x -= left
    return { width: right - left, height: maxDrop, chars: chars }
  }

  readonly property var placed: {
    var _ = metrics.font.family + metrics.font.pixelSize
    var widths = []
    for (var i = 0; i < glyphs.length; i++) widths.push(metrics.advanceWidth(glyphs[i]))
    return arcLayout(widths, rise)
  }

  readonly property real slack: Math.round(metrics.height / 2)
  implicitWidth: Math.ceil(placed.width) + 2 * slack
  implicitHeight: Math.ceil(placed.height + metrics.height)
  readonly property real originX: (width - placed.width) / 2

  Repeater {
    model: root.glyphs.length

    Text {
      required property int index
      readonly property string glyph: root.glyphs[index] || ""
      readonly property var spot: root.placed.chars[index] || { x: 0, y: 0, rotation: 0 }

      width: metrics.advanceWidth(glyph)
      height: metrics.height
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      x: root.originX + spot.x
      y: spot.y
      rotation: spot.rotation
      transformOrigin: Item.Center
      textFormat: Text.PlainText
      text: glyph
      color: root.color
      font.family: root.fontFamily
      font.pixelSize: root.pixelSize
      renderType: Text.QtRendering
    }
  }
}
