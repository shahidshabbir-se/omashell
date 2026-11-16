import QtQuick
import qs.common
import qs.config
import "Model.js" as Model

// One bar indicator. The reference BarIndicator draws each glyph at the bar's
// icon size inside a status slot: 21px wide and bar-high horizontally, icon-
// slot wide and 21px high vertically. Inactive revealed glyphs dim to 45%.
Item {
  id: root

  property string indicatorId: ""
  property string glyph: ""
  property string label: ""
  property bool active: false
  property bool revealed: false
  property bool vertical: false
  signal activated(string indicatorId)
  signal hovered(string indicatorId)
  signal unhovered(string indicatorId)

  // The reference bar's horizontal buttons are 26px high even though the
  // Omashell strip is 28px; keep the reference button extent and let the bar
  // slot center it. A vertical bar uses its own 28px thickness.
  readonly property int buttonThickness: root.vertical
    ? Constants.barHeight
    : Math.min(Constants.barHeight, 26)
  readonly property var slotGeometry: Model.buttonSize(
    root.vertical, root.buttonThickness, Constants.statusSlot)

  implicitWidth: root.slotGeometry.width
  implicitHeight: root.slotGeometry.height
  visible: root.glyph !== ""
  opacity: Model.indicatorOpacity(root.active, root.revealed)

  OpticalGlyph {
    id: glyphItem

    anchors.fill: parent
    text: root.glyph
    fontFamily: Constants.fontFamily
    fontSize: Constants.fontSubtitle
    paintedSize: Constants.iconSize
    color: Colors.foreground
    scale: pointer.containsPress ? 0.9 : 1

    Behavior on scale {
      NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
    }
  }

  MouseArea {
    id: pointer

    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    enabled: root.active || root.revealed
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    onEntered: root.hovered(root.indicatorId)
    onExited: root.unhovered(root.indicatorId)
    // As the reference BarIndicator does, any accepted press toggles the
    // indicator; the action itself is not button-specific.
    onClicked: root.activated(root.indicatorId)
  }

  Behavior on opacity {
    NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
  }
}
