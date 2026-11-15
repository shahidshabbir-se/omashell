import QtQuick
import QtQuick.Controls
import qs.config

                                                                            
                                                                                  
ToolTip {
  id: root

  property color foreground: Colors.tooltipText
  property color backgroundColor: Colors.tooltipBackground
  property color borderColor: Colors.tooltipBorder
  property string fontFamily: Constants.fontFamily
  property int fontSize: Constants.fontBodySmall

  delay: Constants.tooltipDelay
  padding: 0

  background: Rectangle {
    color: root.backgroundColor
    border.width: 1
    border.color: root.borderColor
    radius: Constants.cornerRadius
  }

  contentItem: Text {
    text: root.text
    textFormat: Text.PlainText
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    wrapMode: Text.WordWrap
                                                                   
    leftPadding: 11
    rightPadding: 11
    topPadding: 7
    bottomPadding: 7
  }
}
