import QtQuick
import qs.config

Item {
  id: root
  property string profile: ''
  property bool selected: false
  property bool hasCursor: false
  property bool navigable: true
  property var panelNav: null
  signal activated()
  readonly property string icon: profile === 'power-saver' ? '󰌪' : profile === 'balanced' ? '󰊚' : profile === 'performance' ? '󰓅' : '󰂄'
  readonly property string label: profile === 'power-saver' ? 'Power-saver' : profile === 'balanced' ? 'Balanced' : profile === 'performance' ? 'Performance' : profile.charAt(0).toUpperCase() + profile.slice(1)
  implicitHeight: Math.max(iconText.implicitHeight, labelText.implicitHeight) + 18
  function activate() { activated() }

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b,
      mouse.pressed ? 0.22 : (mouse.containsMouse || root.hasCursor ? 0.08 : (root.selected ? 0.18 : 0)))
    border.width: 1
    border.color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b,
      mouse.containsMouse || root.hasCursor ? 0.25 : 0.4)
    Behavior on color { ColorAnimation { duration: 120 } }
  }
  Row {
    anchors.centerIn: parent
    spacing: 6
    width: Math.min(iconText.implicitWidth + spacing + labelText.implicitWidth, root.width - 8)
    Text {
      id: iconText
      text: root.icon
      color: Colors.foreground
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontTitle
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      id: labelText
      width: Math.min(implicitWidth, Math.max(0, parent.width - iconText.implicitWidth - parent.spacing))
      text: root.label
      color: Colors.foreground
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontBodySmall
      elide: Text.ElideRight
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      anchors.verticalCenter: parent.verticalCenter
    }
  }
  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: if (root.panelNav) root.panelNav.select(root)
    onClicked: root.activate()
  }
}
