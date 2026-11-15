import QtQuick
import qs.config

                                                                
  
                                                                                
                                                                                
                                                                           
  
                                                                               
                                                                                  
                                                                                 
                         
  
                                                                                   
                                                                     
Item {
  id: root

  property bool checked: false
  property bool busy: false
  property string navGroup: ""
  property bool navigable: true
  property bool hasCursor: false
  property var panelNav: null
  property string navigationKey: ""

  property color foreground: Colors.foreground

                                                   
  property int cursorPad: 6

                                                                                
                                                                                   
                                            
  property bool rounded: Constants.cornerRadius > 0

  property int trackHeight: 22
  property int trackWidth: Math.round(trackHeight * 1.9)
  property int knobSize: Math.max(6, Math.round(trackHeight * 0.72))
  property int knobInset: Math.max(1, Math.round((trackHeight - knobSize) / 2))

  signal toggled()
  readonly property bool containsMouse: mouse.containsMouse

  implicitWidth: root.trackWidth + root.cursorPad * 2
  implicitHeight: root.trackHeight + root.cursorPad * 2

  function activate() {
    if (root.busy) return
                                                                          
    root.toggled()
  }

                                                    
  Rectangle {
    anchors.fill: parent
    visible: root.hasCursor
    color: "transparent"
    radius: root.rounded ? Math.min(width, height) / 2 : 0
    border.width: 1
    border.color: root.shade(0.25)
  }

                                                                     
  function shade(alpha) {
    return Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, alpha)
  }

  Rectangle {
    id: track

    width: root.trackWidth
    height: root.trackHeight
    anchors.centerIn: parent
    radius: root.rounded ? height / 2 : 0
                                                                             
                                                               
    color: root.checked ? root.shade(0.18) : root.shade(0.04)
    border.width: root.checked ? 0 : 1
    border.color: root.shade(0.4)

    Behavior on color {
      ColorAnimation { duration: 120 }
    }

    Rectangle {
      id: knob

      width: root.knobSize
      height: root.knobSize
      radius: root.rounded ? height / 2 : 0
      anchors.verticalCenter: parent.verticalCenter
      x: root.checked ? track.width - width - root.knobInset : root.knobInset
      color: root.checked ? root.foreground : Qt.darker(root.foreground, 1.25)

      Behavior on x {
        NumberAnimation {
          duration: 120
          easing.type: Easing.OutCubic
        }
      }

      Behavior on color {
        ColorAnimation { duration: 120 }
      }
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
