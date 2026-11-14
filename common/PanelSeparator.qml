import QtQuick
import qs.config

// 1px divider for panel sections, drawn as foreground at a low alpha so the rule
// stays legible against the panel background without competing with the text.
//
// A "1px" logical rule is not one pixel on every output: at a 4/3 ratio it covers
// 1.33 physical rows, so it renders across two of them and some rules look twice
// as thick as others purely because of where they land. This draws exactly one
// *physical* row (1 / dpr) and then nudges it onto a whole physical pixel with a
// translate, which does not disturb the layout.
Rectangle {
  id: root

  property color foreground: Colors.foreground
  property real strength: 0.12
  // The output's pixel ratio; defaults to 1 when a caller does not pass it.
  property real pixelRatio: 1

  readonly property real dpr: root.pixelRatio > 0 ? root.pixelRatio : 1
  // One physical pixel, expressed in logical units.
  implicitHeight: 1 / root.dpr
  height: 1 / root.dpr

  width: parent ? parent.width : implicitWidth
  implicitWidth: 100

  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, root.strength)

  // Shift by the fraction between the painted position and the nearest physical
  // pixel, so every rule starts on a whole row.
  readonly property real snap: {
    if (!root.dpr) return 0
    var point = root.mapToItem(null, 0, 0)
    var physical = point.y * root.dpr
    return (Math.round(physical) - physical) / root.dpr
  }

  transform: Translate { y: root.snap }
}
