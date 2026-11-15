import QtQuick
import qs.config

                                                                                 
                                                                              
  
                                                                                  
                                                                                 
                                                                               
                                                                                 
                                                
Rectangle {
  id: root

  property color foreground: Colors.foreground
  property real strength: 0.12
                                                                            
  property real pixelRatio: 1

  readonly property real dpr: root.pixelRatio > 0 ? root.pixelRatio : 1
                                                    
  implicitHeight: 1 / root.dpr
  height: 1 / root.dpr

  width: parent ? parent.width : implicitWidth
  implicitWidth: 100

  color: Qt.rgba(root.foreground.r, root.foreground.g, root.foreground.b, root.strength)

                                                                                
                                                
  readonly property real snap: {
    if (!root.dpr) return 0
    var point = root.mapToItem(null, 0, 0)
    var physical = point.y * root.dpr
    return (Math.round(physical) - physical) / root.dpr
  }

  transform: Translate { y: root.snap }
}
