import QtQuick
import QtQml
import qs.config
import qs.modules.bar

                                                                              
                                                                    
Row {
  id: root

                                                                                     
                                                                                
  spacing: 0

                                                                                
                                                                                 
                                                                        
  height: Constants.barHeight

                                                                               
  property var ids: []

  readonly property real clockCenter: {
    var count = widgets.count
    for (var i = 0; i < count; i++) {
      var item = widgets.itemAt(i)
      if (item && item.widgetId === "clock" && item.visible) return item.x + item.width / 2
    }
    return width / 2
  }

                                                                              
                                                  
  property var screen: null

                                                                         
                                                                              
  property string activeId: ""

                                                                      
  signal activated(string id, real centerX)

                                                                     
  signal tooltipEntered(var slot, string text, real centerX)
  signal tooltipLeft(var slot)

  property Item hoverSlot: null

  function setHovered(slot) {
    if (root.hoverSlot && root.hoverSlot !== slot) root.tooltipLeft(root.hoverSlot)
    root.hoverSlot = slot
    if (slot) root.tooltipEntered(slot, slot.tooltipText, slot.x + slot.width / 2)
  }

  Repeater {
    id: widgets
    model: root.ids

    delegate: Item {
      id: slot

      readonly property string widgetId: modelData

                                                                              
                                                                          
                                                               
      readonly property real contentWidth: loader.implicitWidth
                                                                                    
                                                                                    
                                                                                  
                          
      readonly property real slotWidth: loader.item && loader.item.barSlotWidth !== undefined
        ? loader.item.barSlotWidth
        : slot.contentWidth + Constants.barWidgetPadding * 2

      width: slotWidth
      height: root.height
                                                                                 
      visible: loader.status === Loader.Ready

                                                                                  
                                                                                  
                                                                               
                                      
                                                             
      readonly property string tooltipText: loader.item && loader.item.tooltip !== undefined
        ? String(loader.item.tooltip)
        : ""
      onTooltipTextChanged: if (root.hoverSlot === slot)
        root.tooltipEntered(slot, slot.tooltipText, slot.x + slot.width / 2)

      readonly property Item markItem: loader.item && loader.item.openPanelIndicatorItem !== undefined
        ? loader.item.openPanelIndicatorItem
        : null
      readonly property real markWidth: markItem
        ? markItem.width
        : (loader.item && loader.item.openPanelIndicatorWidth !== undefined
            ? loader.item.openPanelIndicatorWidth
            : slot.contentWidth)
      readonly property real markCenterX: markItem
        ? markItem.mapToItem(slot, markItem.width / 2, 0).x
        : slot.width / 2

      Loader {
        id: loader

        source: WidgetRegistry.urlFor(slot.widgetId)
        anchors.centerIn: parent

        Binding {
          target: loader.item
          property: "screen"
          value: root.screen
          when: loader.item !== null && loader.item.screen !== undefined
          restoreMode: Binding.RestoreNone
        }

                                                                                   
                                                                              
        Binding {
          target: loader.item
          property: "widgetId"
          value: slot.widgetId
          when: loader.item !== null && loader.item.widgetId !== undefined
          restoreMode: Binding.RestoreNone
        }

        Binding {
          target: loader.item
          property: "settings"
          value: Config.widgetSettings[slot.widgetId] !== undefined
            ? Config.widgetSettings[slot.widgetId]
            : ({})
          when: loader.item !== null && loader.item.settings !== undefined
          restoreMode: Binding.RestoreNone
        }

                                                                            
                                                                                   
        Connections {
          target: loader.item
          ignoreUnknownSignals: true

          function onActivated() {
            root.activated(slot.widgetId, slot.x + loader.x + loader.width / 2)
          }

          function onCalendarToggleRequested() {
            root.activated(slot.widgetId, slot.x + loader.x + loader.width / 2)
          }

          function onToggleRequested() {
            root.activated(slot.widgetId, slot.x + loader.x + loader.width / 2)
          }
        }
      }

      Component.onDestruction: if (root.hoverSlot === slot) root.setHovered(null)

      HoverHandler {
        onHoveredChanged: {
          if (hovered) root.setHovered(slot)
          else if (root.hoverSlot === slot) root.setHovered(null)
        }
      }

                                                                                 
                                                                                  
                                                                                 
                                                                            
                            
      Rectangle {
        id: indicator

        visible: opacity > 0
        opacity: root.activeId === slot.widgetId ? 0.9 : 0
        color: Colors.accent
        radius: Math.min(width, height) / 2
        width: slot.markWidth
        height: Constants.indicatorThickness
        x: Math.floor(slot.markCenterX - width / 2)
        y: slot.height - height - Constants.indicatorInset
        z: 10

        Behavior on opacity {
          NumberAnimation {
            duration: 120
            easing.type: Easing.OutCubic
          }
        }
      }
    }
  }
}
