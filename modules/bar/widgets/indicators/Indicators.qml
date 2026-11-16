import QtQuick
import qs.config
import qs.modules.notifications
import qs.modules.bar.widgets.indicators
import "Model.js" as Model

// The two state indicators this independent bar implements: notification
// silencing and stay-awake inhibition. Ids, glyphs, tooltips, reveal behavior,
// and slot geometry follow the Omarchy bar indicators.
Item {
  id: root

  property string widgetId: "indicators"
  property var settings: ({})
  property var screen: null
  property string fixedEdge: "center"
  property var bar: null
  property string hoveredId: ""

  readonly property bool vertical: root.bar ? root.bar.vertical === true : false
  readonly property var indicatorIds: Model.itemsFromSettings(root.settings)
  readonly property bool alwaysShowIndicators: root.settings && root.settings.alwaysShow === true
  readonly property bool areaHovered: indicatorHover.hovered
  readonly property bool revealInactive: root.alwaysShowIndicators || root.areaHovered
    || (root.bar && root.bar.centerSectionRevealHeld === true)
  readonly property var displayed: Model.visibleItems(
    root.indicatorIds, NotificationService.dnd, StayAwakeService.active,
    root.revealInactive, root.fixedEdge)
  readonly property var widgetGeometry: Model.widgetSize(
    root.vertical, root.displayed.length, Constants.barHeight, Constants.statusSlot)
  readonly property bool available: root.displayed.length > 0
  readonly property string tooltip: {
    if (root.hoveredId === "") return ""
    var active = Model.isActive(root.hoveredId, NotificationService.dnd, StayAwakeService.active)
    return Model.tooltipFor(root.hoveredId, active, StayAwakeService.supported)
  }

  function activate(id) {
    var normalized = Model.normalizeId(id)
    if (normalized === "Dnd") NotificationService.toggleDnd()
    else if (normalized === "StayAwake") StayAwakeService.toggle()
  }

  visible: root.available
  implicitWidth: root.widgetGeometry.width
  implicitHeight: root.widgetGeometry.height
  readonly property real barSlotWidth: root.widgetGeometry.width
  readonly property real barSlotHeight: root.widgetGeometry.height

  Loader {
    id: orientationLoader
    anchors.centerIn: parent
    sourceComponent: root.vertical ? verticalBlock : horizontalBlock
  }

  Component {
    id: horizontalBlock

    Row {
      spacing: 0

      Repeater {
        model: root.displayed

        IndicatorButton {
          required property var modelData

          indicatorId: modelData.id
          glyph: Model.glyphFor(modelData.id)
          label: Model.labelFor(modelData.id)
          active: modelData.active
          revealed: root.revealInactive
          vertical: false
          onActivated: function(id) { root.activate(id) }
          onHovered: function(id) { root.hoveredId = id }
          onUnhovered: function(id) { if (root.hoveredId === id) root.hoveredId = "" }
        }
      }
    }
  }

  Component {
    id: verticalBlock

    Column {
      spacing: 0

      Repeater {
        model: root.displayed

        IndicatorButton {
          required property var modelData

          indicatorId: modelData.id
          glyph: Model.glyphFor(modelData.id)
          label: Model.labelFor(modelData.id)
          active: modelData.active
          revealed: root.revealInactive
          vertical: true
          onActivated: function(id) { root.activate(id) }
          onHovered: function(id) { root.hoveredId = id }
          onUnhovered: function(id) { if (root.hoveredId === id) root.hoveredId = "" }
        }
      }
    }
  }

  HoverHandler {
    id: indicatorHover
  }
}
