import QtQuick
import qs.common
import qs.config

                                                                              
                                                                              
                                                                 
Item {
  id: root

  property string glyph: ""
  property string tooltipText: ""
  property string navGroup: ""
  property bool navigable: true
  property bool hasCursor: false
  property var panelNav: null

  signal activated()

  implicitWidth: 26
  implicitHeight: 26

  function activate() {
    root.activated()
  }

  Rectangle {
    anchors.fill: parent
    radius: Constants.cornerRadius
    color: mouse.containsMouse ? Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.08)
      : "transparent"
    border.width: root.hasCursor ? 1 : 0
    border.color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.35)
  }

  OpticalGlyph {
    anchors.fill: parent
    text: root.glyph
    fontSize: Constants.fontTitle
    paintedSize: Constants.fontTitle
    color: Colors.foreground
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: if (root.panelNav) root.panelNav.select(root)
    onClicked: root.activate()

    PanelToolTip {
      visible: mouse.containsMouse && root.tooltipText !== "" && !root.hasCursor
      text: root.tooltipText
      fontFamily: Constants.fontFamily
    }
  }
}
