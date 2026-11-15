import QtQuick
import qs.config
import qs.modules.bar.widgets.audio
import 'Model.js' as Model

Item {
  id: root
  property var row: null
  property var panelNav: null
  property bool navigable: true
  property bool hasCursor: false
  readonly property var node: AudioService.resolve(row)
  readonly property real volume: node && node.audio ? node.audio.volume : 0
  readonly property bool muted: !!(node && node.audio && node.audio.muted)
  implicitHeight: content.implicitHeight + 12
  function activate() { AudioService.toggleMute(node) }
  function toggleMute() { activate() }
  function adjust(direction) { AudioService.setVolume(node, volume + direction * 0.05, 1.5) }

  Rectangle {
    anchors.fill: parent
    color: root.hasCursor ? Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.08) : 'transparent'
    border.width: root.hasCursor ? 1 : 0
    border.color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.25)
  }
  Column {
    id: content
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: 6
    anchors.rightMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2
    Row {
      width: parent.width
      spacing: 8
      Text {
        id: muteIcon
        text: root.muted ? '󰝟' : '󰕾'
        width: 22
        horizontalAlignment: Text.AlignHCenter
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontTitle
        color: Colors.foreground
        opacity: root.muted ? 0.5 : 1
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.activate() }
      }
      Text {
        width: Math.max(0, parent.width - 22 - 36 - 16)
        text: Model.streamLabel(root.node)
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontBody
        color: Colors.foreground
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        elide: Text.ElideRight
      }
      Text {
        width: 36
        horizontalAlignment: Text.AlignRight
        text: Math.round(root.volume * 100) + '%'
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontCaption
        font.bold: true
        color: Qt.darker(Colors.foreground, 1.5)
        opacity: root.muted ? 0.5 : 1
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
      }
    }
    AudioSlider {
      width: parent.width
      navigable: false
      value: root.volume
      maximum: 1.5
      opacity: root.muted ? 0.5 : 1
      onMoved: function(value) { AudioService.setVolume(root.node, value, 1.5) }
      onMuteRequested: root.activate()
    }
  }
  HoverHandler { onHoveredChanged: if (hovered && root.panelNav) root.panelNav.select(root) }
}
