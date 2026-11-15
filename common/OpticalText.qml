import QtQuick
import qs.config

                                                                                  
            
  
                                                                                
                                                                             
                                                                    
                                                                                      
  
                                                                                
                                                                                    
Item {
  id: root

                                                                                
  property bool centerFigures: true
  property string fontFamily: Constants.fontFamily
  property int pixelSize: Constants.fontBody
  property color color: Colors.foreground
  property alias text: label.text

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

                                                                           
                                      
  readonly property real figureOffset: (metrics.descent - metrics.ascent
    + metrics.tightBoundingRect("0").height) / 2

  FontMetrics {
    id: metrics
    font: label.font
  }

  Text {
    id: label

    anchors.centerIn: parent
                                                                      
    anchors.verticalCenterOffset: root.centerFigures && label.text.indexOf("\n") === -1
      ? root.figureOffset
      : 0

    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: root.fontFamily
    font.pixelSize: root.pixelSize
    color: root.color
  }
}
