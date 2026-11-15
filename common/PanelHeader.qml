import QtQuick
import qs.config

                                                                            
                                                                                  
                                                             
  
                                                                               
                                                                                   
                                                                               
                       
Item {
  id: root

  property string icon: ""
  property string title: ""
  property color foreground: Colors.foreground
  property string caption: ""
  property var captions: []
  property int captionInterval: 2800
                                                                          
  property bool rotating: true

                                                                          
  property bool switchVisible: false
  property bool switchChecked: false
  property var panelNav: null
                                                                         
                                                        
  property string switchOnTooltip: "Turn Bluetooth on"
  property string switchOffTooltip: "Turn Bluetooth off"
  property string switchNavigationKey: "bluetooth-switch"
  property string switchNavGroup: ""

                                                
  default property alias trailing: actionsRow.children

  property int captionIndex: 0

  readonly property string captionText: root.captions.length > 0
    ? String(root.captions[root.captionIndex % root.captions.length])
    : root.caption

  signal switchToggled()

  readonly property bool rotatingNow: root.rotating && root.captions.length > 1

  implicitHeight: Math.ceil(Math.max(root.icon ? Constants.fontDisplay : 0,
    titleColumn.implicitHeight,
    trailingRow.implicitHeight))

                                                                                 
                                                  
  Timer {
    interval: root.captionInterval
    running: root.rotatingNow
    repeat: true
    onTriggered: phraseSwap.restart()
  }

  SequentialAnimation {
    id: phraseSwap

    PropertyAnimation {
      target: captionLabel
      property: "opacity"
      to: 0
      duration: 150
      easing.type: Easing.OutCubic
    }

    ScriptAction {
      script: root.captionIndex = (root.captionIndex + 1) % root.captions.length
    }

    PropertyAnimation {
      target: captionLabel
      property: "opacity"
      to: 1
      duration: 200
      easing.type: Easing.OutCubic
    }
  }

  onRotatingNowChanged: if (!root.rotatingNow) {
    phraseSwap.stop()
    captionLabel.opacity = 1
  }

  OpticalGlyph {
    id: iconItem

    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    visible: root.icon !== ""
    width: Constants.fontDisplay
    height: Constants.fontDisplay
    text: root.icon
    fontSize: Constants.fontDisplay
    paintedSize: 0
    color: root.foreground
  }

  Column {
    id: titleColumn

    anchors.left: iconItem.visible ? iconItem.right : parent.left
    anchors.leftMargin: iconItem.visible ? 14 : 0
    anchors.right: trailingRow.left
    anchors.rightMargin: 12
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2

    Text {
      text: root.title
      color: root.foreground
      font.family: Constants.fontFamily
                                                                           
      font.pixelSize: Constants.fontTitle
      font.bold: true
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
    }

    Text {
      id: captionLabel

      visible: root.captionText !== ""
      text: root.captionText.toUpperCase()
                                                                            
                                                                             
      color: Qt.darker(root.foreground, 1.4)
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontCaption
      font.bold: true
      font.letterSpacing: 1.2
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
    }
  }

  Row {
    id: trailingRow

    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Constants.gap

    Row {
      id: actionsRow
      anchors.verticalCenter: parent.verticalCenter
      spacing: Constants.gap
    }

    ToggleSwitch {
      visible: root.switchVisible
      checked: root.switchChecked
      foreground: root.foreground
      panelNav: root.panelNav
      navigationKey: root.switchNavigationKey
      navGroup: root.switchNavGroup
      onToggled: root.switchToggled()

      PanelToolTip {
        visible: parent.containsMouse
        text: parent.checked ? root.switchOffTooltip : root.switchOnTooltip
        fontFamily: Constants.fontFamily
      }
    }
  }
}
