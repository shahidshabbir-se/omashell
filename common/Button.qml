import QtQuick
import qs.config

                                                                                 
                                                                
Item {
  id: root

  property string text: ""
  property string navGroup: ""
  property var panelNav: null
  property bool navigable: true
  property bool hasCursor: false
  property string navigationKey: ""
  property bool accented: false
  property bool outlined: false
  property bool selected: false
                                                                    
  property bool referenceStates: false
  property int fontSize: Constants.fontBody
  readonly property bool containsMouse: mouse.containsMouse

  signal activated()

  implicitWidth: label.implicitWidth + Constants.panelPadding * 2
  implicitHeight: 26

  function activate() {
    root.activated()
  }

  Rectangle {
    anchors.fill: parent
    radius: Constants.cornerRadius
    color: root.referenceStates
      ? Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b,
          mouse.pressed ? 0.22 : ((root.hasCursor || mouse.containsMouse) ? 0.08 : (root.selected ? 0.18 : 0)))
      : (root.selected ? Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.18)
        : (mouse.containsMouse ? Colors.lighterBackground : "transparent"))
    border.width: root.hasCursor || root.accented || root.outlined ? 1 : 0
    border.color: root.referenceStates
      ? Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b,
          root.hasCursor || mouse.containsMouse ? 0.25 : 0.4)
      : (root.accented ? Colors.accent : (root.outlined ? Colors.darkForeground : Colors.brightForeground))

    Text {
      id: label

      anchors.centerIn: parent
      text: root.text
      color: Colors.foreground
      font.family: Constants.fontFamily
      font.pixelSize: root.fontSize
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
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
