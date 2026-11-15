import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.config
import qs.modules.bar

PanelWindow {
  id: root

  anchors.top: true
  anchors.left: true
  anchors.right: true
  implicitHeight: Constants.barHeight
  color: Colors.background

                                                                                    
  readonly property int sectionMargin: Constants.barSectionMargin

                                                                            
  property string activeId: ""

                                                                              
                                                  
  signal widgetActivated(string id, real anchorX)

                                                            
  property string tooltipText: ""
  property real tooltipX: 0
  property var tooltipTarget: null
  property bool tooltipShown: false
  property int tooltipRequest: 0

                                                                              
                                                                              
  property bool panelOpen: false

  onPanelOpenChanged: if (root.panelOpen) root.clearTooltip()

                                                                                
  signal barClicked()

                                                                         
                                                                          
                                                               
  function clearTooltip() {
    tooltipTimer.stop()
    if (root.tooltipShown) tooltipWarmTimer.restart()
    root.tooltipTarget = null
    root.tooltipText = ""
    root.tooltipShown = false
    root.tooltipRequest++
  }

  function showTooltip(slot, text, centerX, section) {
    var warm = root.tooltipShown || tooltipWarmTimer.running
    root.clearTooltip()
    if (!slot || !text || root.panelOpen) return
    var request = root.tooltipRequest
    root.tooltipTarget = slot
    root.tooltipText = text
    root.tooltipX = root.contentItem.mapFromItem(section, centerX, 0).x
    Qt.callLater(function() {
      if (request !== root.tooltipRequest || root.tooltipTarget !== slot) return
      if (warm) root.tooltipShown = true
      else tooltipTimer.restart()
    })
  }

  function hideTooltip(slot) {
    if (root.tooltipTarget === slot) root.clearTooltip()
  }

  Timer {
    id: tooltipTimer
    interval: Constants.tooltipDelay
    onTriggered: if (root.tooltipTarget && !root.panelOpen) root.tooltipShown = true
  }

  Timer {
    id: tooltipWarmTimer
    interval: Constants.tooltipDelay
  }

                                                                           
                                                                                
                                                                   
  PopupWindow {
    id: tooltipWindow

                                                                               
    anchor.window: root
    anchor.rect.x: Math.round(root.tooltipX - width / 2)
    anchor.rect.y: Constants.barHeight + 6
    anchor.adjustment: PopupAdjustment.Slide
    anchor.rect.width: 1
    anchor.rect.height: 1

    visible: root.tooltipShown && root.tooltipText !== "" && !root.panelOpen
    color: "transparent"
                                                                              
                                                                                  
    implicitWidth: Math.ceil(tooltipLabel.implicitWidth) + 20
    implicitHeight: Math.max(22, Math.ceil(tooltipLabel.implicitHeight) + 14)

                                                                                   
                                                                                    
                                                                                   
                                                                                  
                                     
    property bool revealed: false

    onVisibleChanged: {
      if (!visible) {
        revealed = false
        return
      }
      Qt.callLater(function() { if (tooltipWindow.visible) tooltipWindow.revealed = true })
    }

    Rectangle {
      id: tooltipBubble

      anchors.fill: parent
      opacity: tooltipWindow.revealed ? 1 : 0
      color: Colors.tooltipBackground
      border.width: 1
      border.color: Colors.tooltipBorder
      radius: Constants.cornerRadius

      Text {
        id: tooltipLabel

        anchors.centerIn: parent
        text: root.tooltipText
        color: Colors.tooltipText
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontBody
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
      }
    }
  }

                                                                         
  MouseArea {
    anchors.fill: parent
    onClicked: root.barClicked()
  }

  BarSection {
    id: leftSection

    ids: Config.bar.left
    screen: root.screen
    activeId: root.activeId
    anchors.left: parent.left
    anchors.leftMargin: root.sectionMargin
    anchors.verticalCenter: parent.verticalCenter

    onActivated: function(id, x) {
      root.widgetActivated(id, root.contentItem.mapFromItem(leftSection, x, 0).x)
    }

    onTooltipEntered: function(slot, text, x) { root.showTooltip(slot, text, x, leftSection) }
    onTooltipLeft: function(slot) { root.hideTooltip(slot) }
  }

  BarSection {
    id: centerSection

    ids: Config.bar.center
    screen: root.screen
    activeId: root.activeId
    x: Math.round(parent.width / 2 - clockCenter)
    anchors.verticalCenter: parent.verticalCenter

    onActivated: function(id, x) {
      root.widgetActivated(id, root.contentItem.mapFromItem(centerSection, x, 0).x)
    }

    onTooltipEntered: function(slot, text, x) { root.showTooltip(slot, text, x, centerSection) }
    onTooltipLeft: function(slot) { root.hideTooltip(slot) }
  }

  BarSection {
    id: rightSection

    ids: Config.bar.right
    screen: root.screen
    activeId: root.activeId
    anchors.right: parent.right
    anchors.rightMargin: root.sectionMargin
    anchors.verticalCenter: parent.verticalCenter

    onActivated: function(id, x) {
      root.widgetActivated(id, root.contentItem.mapFromItem(rightSection, x, 0).x)
    }

    onTooltipEntered: function(slot, text, x) { root.showTooltip(slot, text, x, rightSection) }
    onTooltipLeft: function(slot) { root.hideTooltip(slot) }
  }
}
