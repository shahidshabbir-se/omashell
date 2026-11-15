import QtQuick
import qs.config
import qs.modules.bar.widgets.audio
import 'Model.js' as Model

Item {
  id: root
  property var row: null
  property bool input: false
  property var panelNav: null
  property bool navigable: true
  property bool hasCursor: false
  readonly property var node: AudioService.resolve(row)
  readonly property var active: input ? AudioService.source : AudioService.sink
  readonly property bool selected: !!row && !!active && row.id === active.id && row.name === String(active.name || '')
  implicitHeight: 30
  function activate() { AudioService.selectDevice(row, input) }
  function toggleMute() { AudioService.toggleMute(input ? AudioService.source : AudioService.sink) }

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, root.hasCursor ? 0.08 : root.selected ? 0.18 : 0)
    border.width: root.hasCursor ? 1 : 0
    border.color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.25)
  }
  Row {
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: 6
    anchors.rightMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    spacing: 8
    Text {
      text: Model.deviceIcon(root.node, root.input)
      width: 22
      horizontalAlignment: Text.AlignHCenter
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontTitle
      color: Colors.foreground
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
    }
    Text {
      text: Model.label(root.node)
      width: parent.width - 30
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontBody
      font.bold: root.selected
      color: Colors.foreground
      elide: Text.ElideRight
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
    }
  }
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: if (root.panelNav) root.panelNav.select(root)
    onClicked: root.activate()
  }
}
