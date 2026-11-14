import QtQuick
import qs.config

// Panel header: icon, heading, an optional second line that rotates through
// phrases, and an optional switch at the end. One reusable piece so every panel's
// chrome matches without each panel rebuilding the same row.
//
// The rotating line is off unless `captions` has more than one entry; a single
// `caption` string stays put. "Changing text" is the point here: a panel that does
// something ongoing (scanning, connecting) says so, instead of the same static
// subtitle every time.
Item {
  id: root

  property string icon: ""
  property string title: ""
  property color foreground: Colors.foreground
  property string caption: ""
  property var captions: []
  property int captionInterval: 2800
  // Rotation only while it makes sense to animate (panel open, radio on).
  property bool rotating: true

  // Built-in switch, for a panel whose header is also its on/off control.
  property bool switchVisible: false
  property bool switchChecked: false
  property var panelNav: null

  // Anything else at the end, after the switch.
  default property alias trailing: trailingRow.children

  property int captionIndex: 0

  readonly property string captionText: root.captions.length > 0
    ? String(root.captions[root.captionIndex % root.captions.length])
    : root.caption

  signal switchToggled()

  readonly property bool rotatingNow: root.rotating && root.captions.length > 1

  implicitHeight: Math.ceil(Math.max(root.icon ? Constants.fontDisplay : 0,
    titleColumn.implicitHeight,
    trailingRow.implicitHeight))

  // Swap with a fade, not an instant text change: fade the line out, advance the
  // index while it is invisible, fade it back in.
  Timer {
    interval: root.captionInterval
    running: root.rotatingNow
    repeat: true
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap

    PropertyAnimation {
      target: captionLabel
      property: "opacity"
      to: 0
      duration: 150
      easing.type: Easing.OutCubic
    }

    ScriptAction {
      script: root.captionIndex = (root.captionIndex + 1) % root.captions.length
    }

    PropertyAnimation {
      target: captionLabel
      property: "opacity"
      to: 1
      duration: 200
      easing.type: Easing.OutCubic
    }
  }

  onRotatingNowChanged: if (!root.rotatingNow) {
    phraseSwap.stop()
    captionLabel.opacity = 1
  }

  OpticalGlyph {
    id: iconItem

    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    visible: root.icon !== ""
    width: Constants.fontDisplay
    height: Constants.fontDisplay
    text: root.icon
    fontSize: Constants.fontDisplay
    paintedSize: 0
    color: root.foreground
  }

  Column {
    id: titleColumn

    anchors.left: iconItem.visible ? iconItem.right : parent.left
    anchors.leftMargin: iconItem.visible ? 14 : 0
    anchors.right: trailingRow.left
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2

    Text {
      text: root.title
      color: root.foreground
      font.family: Constants.fontFamily
      // Matches the other side: title size, and bold rather than semibold.
      font.pixelSize: Constants.fontTitle
      font.bold: true
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
    }

    Text {
      id: captionLabel

      visible: root.captionText !== ""
      text: root.captionText.toUpperCase()
      // Dim from the foreground, not a separate dim token, and bold + wider
      // tracking - that is what makes the line read as a header, not a hint.
      color: Qt.darker(root.foreground, 1.4)
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontCaption
      font.bold: true
      font.letterSpacing: 1.2
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
    }
  }

  Row {
    id: trailingRow

    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Constants.gap

    ToggleSwitch {
      visible: root.switchVisible
      checked: root.switchChecked
      foreground: root.foreground
      panelNav: root.panelNav
      navigationKey: "bluetooth-switch"
      onToggled: root.switchToggled()

      PanelToolTip {
        visible: parent.containsMouse
        text: parent.checked ? "Turn Bluetooth off" : "Turn Bluetooth on"
        fontFamily: Constants.fontFamily
      }
    }
  }
}
