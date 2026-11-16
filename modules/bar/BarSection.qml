import QtQuick
import QtQuick.Layouts
import QtQml
import qs.config
import qs.modules.bar
import "BarModel.js" as BarModel
import "BarSectionModel.js" as BarSectionModel

                                                                              
                                                                    
GridLayout {
  id: root

                                                                                     
                                                                                
  flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
  rowSpacing: 0
  columnSpacing: 0
  rows: root.vertical ? -1 : 1
  columns: root.vertical ? 1 : -1
  property bool vertical: bar ? bar.vertical : false

                                                                                
                                                                                 
                                                                        
  width: root.vertical ? Constants.barHeight : implicitWidth
  height: root.vertical ? implicitHeight : Constants.barHeight

  property var ids: []
  property string sectionName: "left"
  property var bar: null

                                                                              
                                                  
  property var screen: null

                                                                         
                                                                              
  property string activeId: ""

                                                                      
  signal activated(string id, real centerX)

                                                                     
  signal tooltipEntered(var slot, string text, real centerX)
  signal tooltipLeft(var slot)

  property Item hoverSlot: null
  readonly property bool dragActive: root.bar ? root.bar.widgetDrag !== null : false
  onDragActiveChanged: if (dragActive) root.setHovered(null)

  function coordinateFor(slot) {
    return root.vertical ? slot.y + slot.height / 2 : slot.x + slot.width / 2
  }

  function activationCoordinate(slot, loader) {
    return root.vertical
      ? slot.y + loader.y + loader.height / 2
      : slot.x + loader.x + loader.width / 2
  }

  function setHovered(slot) {
    if (root.dragActive) {
      if (root.hoverSlot) root.tooltipLeft(root.hoverSlot)
      root.hoverSlot = null
      return
    }
    if (root.hoverSlot && root.hoverSlot !== slot) root.tooltipLeft(root.hoverSlot)
    root.hoverSlot = slot
    if (slot) root.tooltipEntered(slot, slot.tooltipText, root.coordinateFor(slot))
  }

  function countVisible() {
    var count = 0
    for (var i = 0; i < widgets.count; i++) {
      var slot = widgets.itemAt(i)
      if (slot && slot.visible) count++
    }
    return count
  }

  readonly property int visibleCount: root.countVisible()

  function visibleIndexFor(targetSlot) {
    var index = 0
    for (var i = 0; i < widgets.count; i++) {
      var slot = widgets.itemAt(i)
      if (!slot || !slot.visible) continue
      if (slot === targetSlot) return index
      index++
    }
    return -1
  }

  function positionForPlace(place) {
    var index = 0
    for (var i = 0; i < widgets.count; i++) {
      var slot = widgets.itemAt(i)
      if (!slot || !slot.visible) continue
      if (index === place)
        return root.vertical ? root.y + slot.y : root.x + slot.x
      index++
    }
    return root.vertical ? root.y + root.height : root.x + root.width
  }

  function roomLengthAt(region, place) {
    return root.bar ? root.bar.roomLength(region, place) : 0
  }

  // Visible widget edges in the bar's content coordinates, for the drag's
  // nearest-edge drop targeting. Hidden widgets are not candidates; a target
  // beside a visible widget is stored by id, so their raw entries cannot
  // shift the drop. The held widget keeps its pre-drag rect even as its own
  // slot folds away, so the pointer can always put it back.
  function dropCandidates() {
    var out = []
    var content = root.bar ? root.bar.contentItem : null
    for (var i = 0; i < widgets.count; i++) {
      var slot = widgets.itemAt(i)
      if (!slot || !slot.visible || !slot.widgetId) continue
      var point = content
        ? slot.mapToItem(content, 0, 0)
        : { x: root.x + slot.x, y: root.y + slot.y }
      var source = slot.dragSource ? root.bar.widgetDrag : null
      var origin = source ? source.origin : null
      out.push({
        key: slot.widgetId,
        region: root.sectionName,
        index: i,
        x: origin ? origin.x : point.x,
        y: origin ? origin.y : point.y,
        width: origin ? origin.width : slot.width,
        height: origin ? origin.height : slot.height
      })
    }
    return out
  }

  // Where the target's insertion marker sits along the bar, or -1 when the
  // key is not drawn here.
  function positionForTarget(target) {
    if (!target || target.region !== root.sectionName) return -1
    var origin = root.vertical ? root.y : root.x
    var length = root.vertical ? root.height : root.width
    if (!target.key) return origin + (target.after ? length : 0)
    for (var i = 0; i < widgets.count; i++) {
      var slot = widgets.itemAt(i)
      if (!slot || !slot.visible || slot.widgetId !== target.key) continue
      var start = root.vertical ? root.y + slot.y : root.x + slot.x
      return start + (target.after ? (root.vertical ? slot.height : slot.width) : 0)
    }
    return -1
  }

  // An otherwise empty section has no slot to carry the room, so one
  // invisible cell does. It exists only while a drag opens room there.
  Item {
    id: roomStart
    readonly property real length: root.visibleCount === 0 ? root.roomLengthAt(root.sectionName, 0) : 0
    visible: length > 0
    Layout.preferredWidth: root.vertical ? Constants.barHeight : length
    Layout.preferredHeight: root.vertical ? length : Constants.barHeight
    width: root.vertical ? Constants.barHeight : length
    height: root.vertical ? length : Constants.barHeight
  }

  Repeater {
    id: widgets
    model: root.ids

    delegate: Item {
      id: slot

      required property int index
      required property var modelData
      readonly property var entry: modelData
      readonly property string widgetId: BarModel.entryId(modelData)
      readonly property string fixedEdge: root.sectionName === "left" || root.sectionName === "centerEnd"
        ? "start"
        : (root.sectionName === "right" || root.sectionName === "centerBegin" ? "end" : "center")

                                                                              
                                                                          
                                                               
      readonly property Item widgetItem: loader.item
      readonly property real contentWidth: loader.implicitWidth
                                                                                    
                                                                                    
                                                                                  
                          
      readonly property bool available: !loader.item || loader.item.available === undefined || loader.item.available
      readonly property real slotWidth: !slot.available ? 0 : loader.item && loader.item.barSlotWidth !== undefined
        ? loader.item.barSlotWidth
        : slot.contentWidth + Constants.barWidgetPadding * 2

      readonly property real slotHeight: !slot.available ? 0 : loader.item && loader.item.barSlotHeight !== undefined
        ? loader.item.barSlotHeight
        : Math.max(Constants.barHeight, loader.implicitHeight)

      // The drag opens room by growing the gap before the landing slot, and
      // folds the held widget's own slot to the share of the room still home.
      readonly property bool dragSource: root.bar ? root.bar.widgetDrag !== null && root.bar.widgetDrag.slot === slot : false
      readonly property int place: root.visibleIndexFor(slot)
      readonly property real roomHomeLength: dragSource ? root.roomLengthAt(root.sectionName, place) : 0
      readonly property real roomBefore: !dragSource && place >= 0
        ? root.roomLengthAt(root.sectionName, place)
        : 0
      readonly property real roomAfter: !dragSource && place >= 0 && place === root.visibleCount - 1
        ? root.roomLengthAt(root.sectionName, root.visibleCount)
        : 0
      readonly property real layoutWidth: root.vertical
        ? Constants.barHeight
        : (dragSource ? roomHomeLength : slotWidth)
      readonly property real layoutHeight: root.vertical
        ? (dragSource ? roomHomeLength : slotHeight)
        : Constants.barHeight

      Layout.preferredWidth: layoutWidth
      Layout.preferredHeight: layoutHeight
      Layout.leftMargin: root.vertical ? 0 : roomBefore
      Layout.rightMargin: root.vertical ? 0 : roomAfter
      Layout.topMargin: root.vertical ? roomBefore : 0
      Layout.bottomMargin: root.vertical ? roomAfter : 0
      width: layoutWidth
      height: layoutHeight

      // A widget whose own size changes while it is held (the clock ticks,
      // indicators peek) takes its ghost and drop target with it. Do not let
      // the slot's own room animation look like such a resize.
      onWidthChanged: if (!dragSource && root.bar && root.bar.widgetDrag && root.bar.widgetDrag.slot === slot)
        root.bar.resizeWidgetDrag(slot)
      onHeightChanged: if (!dragSource && root.bar && root.bar.widgetDrag && root.bar.widgetDrag.slot === slot)
        root.bar.resizeWidgetDrag(slot)
                                                                                 
      visible: loader.status === Loader.Ready && slot.available

                                                                                  
                                                                                  
                                                                               
                                      
                                                             
      readonly property string tooltipText: loader.item && loader.item.tooltip !== undefined
        ? String(loader.item.tooltip)
        : ""
      onTooltipTextChanged: if (root.hoverSlot === slot)
        root.tooltipEntered(slot, slot.tooltipText, root.coordinateFor(slot))

      readonly property Item markItem: loader.item && loader.item.openPanelIndicatorItem !== undefined
        ? loader.item.openPanelIndicatorItem
        : null
      readonly property real markWidth: BarSectionModel.indicatorWidth(
        root.vertical ? slot.height : slot.width,
        markItem ? (root.vertical ? markItem.height : markItem.width) : 0,
        loader.item && (root.vertical ? loader.item.openPanelIndicatorHeight : loader.item.openPanelIndicatorWidth) !== undefined
          ? Number(root.vertical ? loader.item.openPanelIndicatorHeight : loader.item.openPanelIndicatorWidth)
          : 0,
        Constants.indicatorMinimumWidth)
      readonly property real markCenter: markItem
        ? (root.vertical
            ? markItem.mapToItem(slot, markItem.width / 2, markItem.height / 2).y
            : markItem.mapToItem(slot, markItem.width / 2, markItem.height / 2).x)
        : (root.vertical ? slot.height / 2 : slot.width / 2)

      Loader {
        id: loader

        source: WidgetRegistry.urlFor(slot.widgetId)
        anchors.centerIn: parent
        opacity: root.bar && root.bar.widgetDrag && root.bar.widgetDrag.slot === slot ? 0 : 1
        // The widget under the drag stops taking pointer presses, so its own
        // MouseArea cannot turn the release into a click after the drag.
        enabled: !(root.bar && root.bar.widgetDrag && root.bar.widgetDrag.slot === slot)

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
            : (slot.entry && typeof slot.entry === "object" ? slot.entry : ({}))
          when: loader.item !== null && loader.item.settings !== undefined
          restoreMode: Binding.RestoreNone
        }

        Binding {
          target: loader.item
          property: "fixedEdge"
          value: slot.fixedEdge
          when: loader.item !== null && loader.item.fixedEdge !== undefined
          restoreMode: Binding.RestoreNone
        }

        Binding {
          target: loader.item
          property: "bar"
          value: root.bar
          when: loader.item !== null && loader.item.bar !== undefined
          restoreMode: Binding.RestoreNone
        }

                                                                            
                                                                                   
        Connections {
          target: loader.item
          ignoreUnknownSignals: true

          function onActivated() {
            if (root.bar && root.bar.widgetClickSuppressed) return
            root.activated(slot.widgetId, root.activationCoordinate(slot, loader))
          }

          function onCalendarToggleRequested() {
            if (root.bar && root.bar.widgetClickSuppressed) return
            root.activated(slot.widgetId, root.activationCoordinate(slot, loader))
          }

          function onToggleRequested() {
            if (root.bar && root.bar.widgetClickSuppressed) return
            root.activated(slot.widgetId, root.activationCoordinate(slot, loader))
          }
        }
      }

      Component.onDestruction: {
        if (root.hoverSlot === slot) root.setHovered(null)
        if (root.bar && root.bar.widgetDrag && root.bar.widgetDrag.slot === slot)
          root.bar.cancelWidgetDrag(slot)
      }

      HoverHandler {
        enabled: !root.dragActive
        onHoveredChanged: {
          if (hovered) root.setHovered(slot)
          else if (root.hoverSlot === slot) root.setHovered(null)
        }
      }

      DragHandler {
        id: widgetDrag
        target: null
        acceptedButtons: Qt.LeftButton
        dragThreshold: Constants.widgetDragThreshold
        onActiveChanged: {
          if (!root.bar) return
          if (active) root.bar.beginWidgetDrag(slot.widgetId, root.sectionName, slot, centroid.position)
          else root.bar.finishWidgetDragLater(slot)
        }
        onCentroidChanged: {
          if (active && root.bar)
            root.bar.updateWidgetDrag(slot, centroid.position)
        }
        onCanceled: if (root.bar) root.bar.cancelWidgetDrag(slot)
      }

                                                                                 
                                                                                  
                                                                                 
                                                                            
                            
      Rectangle {
        id: indicator

        visible: opacity > 0
        opacity: root.activeId === slot.widgetId ? 0.9 : 0
        color: Colors.accent
        radius: Math.min(width, height) / 2
        width: root.vertical ? Constants.indicatorThickness : slot.markWidth
        height: root.vertical ? slot.markWidth : Constants.indicatorThickness
        x: root.vertical
          ? (root.bar && root.bar.position === "left" ? slot.width - width - Constants.indicatorInset : Constants.indicatorInset)
          : Math.floor(slot.markCenter - width / 2)
        y: root.vertical
          ? Math.floor(slot.markCenter - height / 2)
          : (root.bar && root.bar.position === "bottom" ? Constants.indicatorInset : slot.height - height - Constants.indicatorInset)
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
