import QtQuick
import qs.config

                                                            
                                                                              
Item {
  id: root

  property string text: ""
  property bool rule: false
  property color color: Qt.darker(Colors.foreground, 1.4)

  implicitHeight: Math.ceil(label.implicitHeight) + (rule ? Constants.gap : 0)

  Text {
    id: label

    text: root.text.toUpperCase()
    color: root.color
    font.family: Constants.fontFamily
    font.pixelSize: Constants.fontCaption
    font.bold: true
                                                                            
                                                                        
    topPadding: Math.ceil(font.pixelSize * 0.15)
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    width: parent.width
    elide: Text.ElideRight
  }

  Rectangle {
    visible: root.rule
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    height: 1
    color: Colors.muted
  }
}
