import QtQuick
import qs.config

                                                                             
  
                                                                                  
                                                                                 
                                                                                  
  
                                                                               
                                         
Item {
  id: root

  property string text: ""
  property string fontFamily: Constants.fontFamily
  property real fontSize: Constants.fontBody
                                                                       
  property real paintedSize: 0
  property color color: Colors.foreground

  readonly property int renderedFontSize: Math.max(1, Math.round(fontSize))

                                                                                  
                                                                               
                                            
  readonly property int metricsScale: 100
  readonly property rect ink: Qt.rect(
    metrics.tightBoundingRect.x / metricsScale,
    metrics.tightBoundingRect.y / metricsScale,
    metrics.tightBoundingRect.width / metricsScale,
    metrics.tightBoundingRect.height / metricsScale)
  readonly property real tightWidth: Math.max(1, ink.width)
  readonly property real tightHeight: Math.max(1, ink.height)

  readonly property real paintedScale: paintedSize > 0
                                                                              
                                                                               
                                                                             
    ? Math.min(paintedSize / tightHeight, width / tightWidth, height / tightHeight)
    : 1
  readonly property real paintedWidth: tightWidth * paintedScale
  readonly property real paintedHeight: tightHeight * paintedScale
  readonly property real paintedCenterX: glyph.x + (ink.x + tightWidth / 2) * paintedScale
  readonly property real paintedCenterY: glyph.y
    + (glyph.baselineOffset + ink.y + tightHeight / 2) * paintedScale
  readonly property real baselineY: glyph.y + glyph.baselineOffset * paintedScale

  TextMetrics {
    id: metrics
    font.family: root.fontFamily
    font.pixelSize: root.renderedFontSize * root.metricsScale
    text: root.text
  }

  Text {
    id: glyph

    text: root.text
    textFormat: Text.PlainText
    color: root.color
    font.family: root.fontFamily
    font.pixelSize: root.renderedFontSize
    transformOrigin: Item.TopLeft
    scale: root.paintedScale
                                                                                
                                                                                
    x: root.width / 2 - (root.ink.x + root.tightWidth / 2) * root.paintedScale
    y: root.paintedSize > 0
      ? root.height / 2 - (baselineOffset + root.ink.y + root.tightHeight / 2) * root.paintedScale
      : Math.round((root.height - height) / 2)
                                                                          
                                                                                
                                                    
    renderType: root.paintedSize > 0 ? Text.QtRendering : Text.NativeRendering
  }
}
