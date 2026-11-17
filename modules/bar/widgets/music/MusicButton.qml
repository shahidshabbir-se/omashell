import QtQuick
import qs.common
import qs.config
import qs.modules.bar.widgets.music

Widget {
  id: root
  readonly property bool available: MusicRuntime.hasCurrentPlayback
  readonly property real barSlotWidth: Constants.iconSlot
  readonly property string tooltip: MusicRuntime.hasPlayer ? String(MusicRuntime.player.trackTitle || "Music") : "Music"
  signal activated()
  implicitWidth: 21
  implicitHeight: 21

  OpticalGlyph {
    anchors.fill: parent
    text: "󰎈"
    fontSize: Constants.fontBody
    paintedSize: Constants.iconSize
    color: Colors.foreground
  }
  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }
}
