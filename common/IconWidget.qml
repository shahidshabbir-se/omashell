import QtQuick
import qs.config

                                                                               
                                                    
  
                                                                                   
                                                                                   
                                                       
Widget {
  id: root

  property string glyph: ""
                                                                                  
                                                                             
  property color color: Colors.foreground
                                                                                    
  property string tooltip: ""

  readonly property int canvas: 21
                                                                                
                               
  property real glyphSize: Constants.iconSize

  signal activated()

                                                                                  
  readonly property real openPanelIndicatorWidth: glyphItem.paintedWidth
                                                                  
  property real slotWidth: Constants.iconSlot
  readonly property real barSlotWidth: slotWidth

  implicitWidth: canvas
  implicitHeight: canvas

  Item {
    id: visual

    anchors.fill: parent
    scale: mouse.pressed ? 0.9 : 1

    Behavior on scale {
      NumberAnimation {
        duration: 80
        easing.type: Easing.InOutQuad
      }
    }

    OpticalGlyph {
      id: glyphItem

      anchors.fill: parent
      text: root.glyph
      fontSize: Constants.fontBody
      paintedSize: root.glyphSize
      color: root.color
    }
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }
}
