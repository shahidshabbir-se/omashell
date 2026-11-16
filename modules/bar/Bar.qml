import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.config
import qs.modules.bar
import "BarModel.js" as BarModel

PanelWindow {
  id: root

  property string position: Config.bar.position
  readonly property bool vertical: root.position === "left" || root.position === "right"

  anchors.top: root.position === "top" || root.vertical
  anchors.bottom: root.position === "bottom" || root.vertical
  anchors.left: root.position === "left" || !root.vertical
  anchors.right: root.position === "right" || !root.vertical
  implicitWidth: root.vertical ? Constants.barHeight : 0
  implicitHeight: root.vertical ? 0 : Constants.barHeight
  color: Colors.background

                                                                                    
  readonly property int sectionMargin: Constants.barSectionMargin

                                                                            
  property string activeId: ""

                                                                              
                                                  
  signal widgetActivated(string id, real anchorX)

                                                            
  property string tooltipText: ""
  property real tooltipX: 0
  property real tooltipY: 0
  property var tooltipTarget: null
  property bool tooltipShown: false
  property int tooltipRequest: 0

                                                                              
                                                                              
  property bool panelOpen: false
  property bool centerSectionRevealHeld: false
  property var widgetDrag: null
  property var widgetDrop: null
  property bool widgetRemoveArmed: false
  property bool widgetClickSuppressed: false
  property real widgetDragX: 0
  property real widgetDragY: 0
  property real widgetDragOffsetX: 0
  property real widgetDragOffsetY: 0
  property real widgetDragWidth: 0
  property real widgetDragHeight: 0
  property url widgetDragImage: ""
  property var widgetSettle: null
  property real widgetSettleProgress: 0
  property var barDragRoom: null
  property var barDragShares: ({})
  property real barDragExtent: 0
  property string barDragHome: ""
  readonly property var barDragLengths: BarModel.roomLengths(root.barDragExtent, root.barDragShares)
  property bool barMoveActive: false
  property bool barMovePressed: false
  property bool barMoveClickSuppressed: false
  property real barMoveStartX: 0
  property real barMoveStartY: 0
  property string barMoveCandidate: ""

  onPanelOpenChanged: if (root.panelOpen) root.clearTooltip()

  Connections {
    target: Config

    // A layout written from elsewhere while a widget is held leaves this drag
    // pointing at a layout the user never saw. Let go rather than land there.
    function onRawChanged() {
      if (root.widgetDrag && root.widgetDrag.keys !== root.currentLayoutKeys())
        root.cancelWidgetDrag(root.widgetDrag.slot)
    }
  }

  function setCenterSectionReveal(hovered) {
    if (hovered) {
      centerSectionRevealTimer.stop()
      centerSectionRevealHeld = true
    } else {
      centerSectionRevealTimer.restart()
    }
  }

  function sectionByName(name) {
    if (name === "left") return leftSection
    if (name === "centerBegin") return centerBeginSection
    if (name === "center") return centerSection
    if (name === "centerEnd") return centerEndSection
    if (name === "right") return rightSection
    return null
  }

  function barSections() {
    return [leftSection, centerBeginSection, centerSection, centerEndSection, rightSection]
  }

  function configSections() {
    return BarModel.configSections(Config.raw || Config.defaults, Config.defaults.bar)
  }

  function currentLayoutKeys() {
    return JSON.stringify(BarModel.layoutKeys(root.configSections()))
  }

  function dropCandidates() {
    var out = []
    var sections = root.barSections()
    for (var i = 0; i < sections.length; i++) {
      var rows = sections[i].dropCandidates()
      for (var j = 0; j < rows.length; j++) out.push(rows[j])
    }
    return out
  }

  function roomKey(room) {
    return room ? room.region + ":" + room.index : ""
  }

  function roomLength(region, place) {
    return root.barDragLengths[region + ":" + place] || 0
  }

  // The room's start along the bar. A gap before a slot begins where that
  // slot's margin begins, which is the slot's current start minus the room it
  // is carrying. At a section end the last slot's right/bottom margin carries
  // it, so the gap starts before that margin.
  function roomPosition(room) {
    var section = room ? root.sectionByName(room.region) : null
    if (!section) return -1
    if (room.home && root.widgetDrag && root.widgetDrag.origin) {
      return root.vertical ? root.widgetDrag.origin.y : root.widgetDrag.origin.x
    }
    var origin = root.vertical ? section.y : section.x
    if (section.visibleCount === 0) return origin
    var start = section.positionForPlace(room.index)
    return start - root.roomLength(room.region, room.index)
  }

  function roomLengthForDrop() {
    var room = root.barDragRoom
    return room ? root.roomLength(room.region, room.index) : 0
  }

  // Where letting go now would put the dragged widget. The center box is its
  // own drop zone, and a drop at the end of a section is represented by an
  // empty key (BarModel.centerDropTarget).
  function dropAtPoint(point) {
    var source = root.widgetDrag ? { key: root.widgetDrag.id, region: root.widgetDrag.section } : null
    var box = { x: centerSection.x, y: centerSection.y, width: centerSection.width, height: centerSection.height }
    var zone = BarModel.centerDropZone(box, Constants.barHeight, root.vertical)
    var target = BarModel.centerDropTarget(root.dropCandidates(), zone, point, root.vertical, source)
    if (!target) return null
    return { region: target.region, key: target.key || "", after: target.after === true }
  }

  function moveWidgetRoom(drop, close) {
    var drag = root.widgetDrag
    if (!drag) return
    var room = close ? null : BarModel.dropRoom(drop, { region: drag.section, key: drag.id }, root.dropCandidates())
    var key = root.roomKey(room)
    var last = root.roomKey(root.barDragRoom)
    root.barDragRoom = room
    if (key !== last) {
      root.fadeWidgetRoom(0)
      roomFader.start()
    }
  }

  function fadeWidgetRoom(seconds) {
    var target = root.widgetRemoveArmed ? "" : root.roomKey(root.barDragRoom)
    var step = seconds * 1000 / 120
    root.barDragShares = BarModel.fadeShares(root.barDragShares, target, step)
    var done = target
      ? (root.barDragShares[target] || 0) >= 1
      : Object.keys(root.barDragShares).length === 0
    if (done) roomFader.stop()
  }

  function captureWidgetDragGhost(slot) {
    var item = slot ? slot.widgetItem : null
    if (!item) return
    var width = Math.max(1, Math.ceil(root.widgetDragWidth))
    var height = Math.max(1, Math.ceil(root.widgetDragHeight))
    item.grabToImage(function(result) {
      if (root.widgetDrag && root.widgetDrag.slot === slot && result && result.url)
        root.widgetDragImage = result.url
    }, Qt.size(width, height))
  }

  function beginWidgetDrag(id, section, slot, localPoint) {
    if (root.widgetSettle) root.finishWidgetSettle()
    if (root.widgetDrag || !id) return
    var item = slot.widgetItem
    if (!item) return
    var point = slot.mapToItem(root.contentItem, localPoint.x, localPoint.y)
    var itemOrigin = item.mapToItem(root.contentItem, 0, 0)
    var slotOrigin = slot.mapToItem(root.contentItem, 0, 0)
    root.widgetDragX = point.x
    root.widgetDragY = point.y
    root.widgetDragOffsetX = point.x - itemOrigin.x
    root.widgetDragOffsetY = point.y - itemOrigin.y
    root.widgetDragWidth = Math.max(1, item.width)
    root.widgetDragHeight = Math.max(1, item.height)
    root.barDragExtent = Math.ceil(root.vertical ? slot.height : slot.width)
    root.widgetDrag = {
      id: id,
      section: section,
      slot: slot,
      origin: { x: slotOrigin.x, y: slotOrigin.y, width: slot.width, height: slot.height },
      keys: root.currentLayoutKeys(),
      localPoint: { x: localPoint.x, y: localPoint.y }
    }
    root.barDragHome = ""
    root.barDragRoom = null
    root.barDragShares = ({})
    root.moveWidgetRoom(null, false)
    var home = root.roomKey(root.barDragRoom)
    if (home) {
      root.barDragHome = home
      var shares = ({})
      shares[home] = 1
      root.barDragShares = shares
    }
    root.widgetClickSuppressed = true
    widgetClickTimer.stop()
    if (root.panelOpen) root.barClicked()
    root.clearTooltip()
    root.captureWidgetDragGhost(slot)
    root.updateWidgetDrag(slot, localPoint)
  }

  function resizeWidgetDrag(slot) {
    var drag = root.widgetDrag
    if (!drag || drag.slot !== slot || root.widgetSettle) return
    var item = slot.widgetItem
    if (!item) return
    root.widgetDragWidth = Math.max(1, item.width)
    root.widgetDragHeight = Math.max(1, item.height)
    widgetDragRegrab.restart()
    if (drag.localPoint) root.updateWidgetDrag(slot, drag.localPoint)
  }

  function updateWidgetDrag(slot, localPoint) {
    var drag = root.widgetDrag
    if (!drag || drag.slot !== slot || root.widgetSettle) return
    drag.localPoint = { x: localPoint.x, y: localPoint.y }
    var point = slot.mapToItem(root.contentItem, localPoint.x, localPoint.y)
    root.widgetDragX = point.x
    root.widgetDragY = point.y

    // The window is the bar strip. Measure the strip explicitly so a future
    // full-screen bar surface does not move the removal threshold with it.
    var stripWidth = root.vertical ? Constants.barHeight : root.contentItem.width
    var stripHeight = root.vertical ? root.contentItem.height : Constants.barHeight
    var distance = BarModel.dragDistanceOutside(point, stripWidth, stripHeight)
    if (distance > 0) {
      root.widgetRemoveArmed = distance >= Constants.widgetRemoveDistance
      root.moveWidgetRoom(null, root.widgetRemoveArmed)
      root.widgetDrop = null
      return
    }

    root.widgetRemoveArmed = false
    var target = root.dropAtPoint(point)
    root.moveWidgetRoom(target, false)
    if (!target) {
      root.widgetDrop = null
      return
    }
    var position = root.roomPosition(root.barDragRoom)
    root.widgetDrop = position < 0 ? null : {
      region: target.region,
      key: target.key,
      after: target.after,
      position: position
    }
  }

  function clearWidgetDrag() {
    widgetDragRegrab.stop()
    widgetSettleAnimation.stop()
    roomFader.stop()
    root.widgetSettle = null
    root.widgetSettleProgress = 0
    root.widgetDrag = null
    root.widgetDrop = null
    root.widgetRemoveArmed = false
    root.widgetDragImage = ""
    root.widgetDragWidth = 0
    root.widgetDragHeight = 0
    root.barDragRoom = null
    root.barDragShares = ({})
    root.barDragExtent = 0
    root.barDragHome = ""
  }

  function suppressWidgetClicks() {
    root.widgetClickSuppressed = true
    widgetClickTimer.restart()
  }

  function cancelWidgetDrag(slot) {
    var drag = root.widgetDrag
    if (!drag || (slot && drag.slot !== slot)) return
    root.clearWidgetDrag()
    root.suppressWidgetClicks()
  }

  function finishWidgetDragLater(slot) {
    if (!root.widgetDrag || root.widgetDrag.slot !== slot) return
    // Qt emits activeChanged false before canceled. Waiting one event loop
    // lets a canceled drag clear the state first, so only a real release
    // writes the layout.
    Qt.callLater(function() { root.finishWidgetDrag(slot) })
  }

  function startWidgetSettle(drag, drop) {
    var from = root.screenPoint(root.widgetDragX, root.widgetDragY)
    var extent = root.barDragExtent
    var along = drop.position + extent / 2
    var centerX = root.vertical ? Constants.barHeight / 2 : along
    var centerY = root.vertical ? along : Constants.barHeight / 2
    var landing = root.screenPoint(centerX, centerY)
    root.widgetSettle = {
      fromX: from.x - root.widgetDragOffsetX,
      fromY: from.y - root.widgetDragOffsetY,
      toX: landing.x - root.widgetDragWidth / 2,
      toY: landing.y - root.widgetDragHeight / 2,
      drag: drag,
      drop: drop
    }
    root.widgetSettleProgress = 0
    widgetSettleAnimation.restart()
  }

  function finishWidgetSettle() {
    var settle = root.widgetSettle
    if (!settle) return
    widgetSettleAnimation.stop()
    root.widgetSettle = null
    root.widgetSettleProgress = 0
    var drag = settle.drag
    var drop = settle.drop
    root.clearWidgetDrag()
    root.suppressWidgetClicks()
    if (!drag || drag.keys !== root.currentLayoutKeys()) return
    root.mutateLayout(function(sections) {
      return BarModel.moveWidgetById(sections, { region: drag.section, id: drag.id }, drop)
    })
  }

  function finishWidgetDrag(slot) {
    var drag = root.widgetDrag
    if (!drag || drag.slot !== slot) return
    if (drag.keys !== root.currentLayoutKeys()) {
      root.cancelWidgetDrag(slot)
      return
    }
    var source = { region: drag.section, id: drag.id }
    var drop = root.widgetDrop
    if (root.widgetRemoveArmed) {
      root.clearWidgetDrag()
      root.suppressWidgetClicks()
      root.mutateLayout(function(sections) {
        return BarModel.removeWidgetById(sections, source.region, source.id) !== null
      })
      return
    }
    if (drop) {
      root.startWidgetSettle(drag, drop)
      return
    }
    root.clearWidgetDrag()
    root.suppressWidgetClicks()
  }

  function mutateLayout(edit) {
    var sections = root.configSections()
    if (!edit(sections)) return false
    Config.mutateBar(function(bar) {
      for (var i = 0; i < BarModel.sectionNames.length; i++) {
        var name = BarModel.sectionNames[i]
        bar[name] = sections[name]
      }
    })
    return true
  }

  function screenPoint(x, y) {
    return {
      x: x + (root.position === "right" ? root.screen.width - Constants.barHeight : 0),
      y: y + (root.position === "bottom" ? root.screen.height - Constants.barHeight : 0)
    }
  }

  function nearestEdge(point) {
    var nx = point.x / Math.max(1, root.screen.width)
    var ny = point.y / Math.max(1, root.screen.height)
    var candidates = [
      { edge: "top", distance: ny },
      { edge: "bottom", distance: 1 - ny },
      { edge: "left", distance: nx },
      { edge: "right", distance: 1 - nx }
    ]
    candidates.sort(function(a, b) { return a.distance - b.distance })
    return candidates[0].edge
  }

  function beginBarMove(x, y) {
    if (root.widgetDrag) return
    root.barMoveActive = true
    root.updateBarMove(x, y)
  }

  function updateBarMove(x, y) {
    if (!root.barMoveActive) return
    root.barMoveCandidate = root.nearestEdge(root.screenPoint(x, y))
  }

  function finishBarMove() {
    var edge = root.barMoveCandidate
    root.barMoveActive = false
    root.barMoveCandidate = ""
    if (edge && edge !== root.position)
      Config.mutateBar(function(bar) { bar.position = edge })
  }

  function cancelBarMove() {
    root.barMoveActive = false
    root.barMoveCandidate = ""
  }

  Timer {
    id: centerSectionRevealTimer
    interval: 120
    onTriggered: root.centerSectionRevealHeld = false
  }

  Timer {
    id: widgetDragRegrab
    interval: 120
    onTriggered: root.captureWidgetDragGhost(root.widgetDrag ? root.widgetDrag.slot : null)
  }

  Timer {
    id: widgetClickTimer
    interval: 200
    onTriggered: root.widgetClickSuppressed = false
  }

  FrameAnimation {
    id: roomFader
    onTriggered: root.fadeWidgetRoom(frameTime)
  }

  NumberAnimation {
    id: widgetSettleAnimation
    target: root
    property: "widgetSettleProgress"
    from: 0
    to: 1
    duration: 180
    easing.type: Easing.OutCubic
    onFinished: root.finishWidgetSettle()
  }

                                                                                
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
    if (root.widgetDrag) {
      root.clearTooltip()
      return
    }
    var warm = root.tooltipShown || tooltipWarmTimer.running
    root.clearTooltip()
    if (!slot || !text || root.panelOpen) return
    var request = root.tooltipRequest
    root.tooltipTarget = slot
    root.tooltipText = text
    var point = root.vertical
      ? root.contentItem.mapFromItem(section, 0, centerX)
      : root.contentItem.mapFromItem(section, centerX, 0)
    root.tooltipX = point.x
    root.tooltipY = point.y
    Qt.callLater(function() {
      if (request !== root.tooltipRequest || root.tooltipTarget !== slot) return
      if (root.widgetDrag) return
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
    onTriggered: if (root.tooltipTarget && !root.panelOpen && !root.widgetDrag) root.tooltipShown = true
  }

  Timer {
    id: tooltipWarmTimer
    interval: Constants.tooltipDelay
  }

                                                                           
                                                                                
                                                                   
  PopupWindow {
    id: tooltipWindow

                                                                               
    anchor.window: root
    anchor.rect.x: root.vertical
      ? (root.position === "left" ? Constants.barHeight + 6 : -width - 6)
      : Math.round(root.tooltipX - width / 2)
    anchor.rect.y: root.vertical
      ? Math.round(root.tooltipY - height / 2)
      : (root.position === "bottom" ? -height - 6 : Constants.barHeight + 6)
    anchor.adjustment: PopupAdjustment.Slide
    anchor.rect.width: 1
    anchor.rect.height: 1

    visible: root.tooltipShown && root.tooltipText !== "" && !root.panelOpen
    color: "transparent"
                                                                              
                                                                                  
    implicitWidth: Math.ceil(tooltipLabel.implicitWidth) + 22
    implicitHeight: Math.max(24, Math.ceil(tooltipLabel.implicitHeight) + 16)

                                                                                   
                                                                                    
                                                                                   
                                                                                  
                                     
    // Each show maps a fresh surface at a whole-number scale before Qt receives
    // the output's fractional one. Keep the bubble transparent until it matches
    // the bar, or its one-pixel border can disappear at 1.25x and similar scales.
    readonly property bool scaleReady: visible && Math.round(devicePixelRatio * 120) === Math.round(root.devicePixelRatio * 120)
    property bool revealed: false

    // Only hiding resets it: at a whole-number scale the ratio dips to 1 after
    // the first frame.
    onVisibleChanged: if (!visible) revealed = false
    onScaleReadyChanged: if (scaleReady) Qt.callLater(function() {
      if (tooltipWindow.scaleReady) tooltipWindow.revealed = true
    })

    Rectangle {
      id: tooltipBubble

      readonly property real pixel: 1 / Math.max(1, tooltipWindow.devicePixelRatio)
      readonly property real inset: Math.ceil(tooltipWindow.devicePixelRatio) * pixel
      x: inset
      y: inset
      width: Math.max(0, Math.floor((tooltipWindow.width - 2 * inset) / pixel) * pixel)
      height: Math.max(0, Math.floor((tooltipWindow.height - 2 * inset) / pixel) * pixel)
      opacity: tooltipWindow.revealed ? 1 : 0
      color: Colors.tooltipBackground

      Rectangle { x: 0; y: 0; width: parent.width; height: tooltipBubble.pixel; color: Colors.tooltipBorder }
      Rectangle { x: 0; y: parent.height - height; width: parent.width; height: tooltipBubble.pixel; color: Colors.tooltipBorder }
      Rectangle { x: 0; y: 0; width: tooltipBubble.pixel; height: parent.height; color: Colors.tooltipBorder }
      Rectangle { x: parent.width - width; y: 0; width: tooltipBubble.pixel; height: parent.height; color: Colors.tooltipBorder }

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
    id: barBackgroundPointer
    anchors.fill: parent
    pressAndHoldInterval: Constants.barMoveHoldDuration
    onClicked: if (!root.barMoveActive && !root.barMoveClickSuppressed) root.barClicked()
    onPressed: function(mouse) {
      root.barMovePressed = true
      root.barMoveClickSuppressed = false
      root.barMoveStartX = mouse.x
      root.barMoveStartY = mouse.y
    }
    onPressAndHold: function(mouse) {
      if (mouse.button === Qt.LeftButton) root.beginBarMove(mouse.x, mouse.y)
    }
    onPositionChanged: function(mouse) {
      if (!(mouse.buttons & Qt.LeftButton)) return
      if (!root.barMoveActive && barBackgroundPointer.pressed) {
        var distance = Math.abs(mouse.x - root.barMoveStartX) + Math.abs(mouse.y - root.barMoveStartY)
        if (distance >= Constants.widgetDragThreshold) root.beginBarMove(root.barMoveStartX, root.barMoveStartY)
      }
      if (root.barMoveActive) root.updateBarMove(mouse.x, mouse.y)
    }
    onReleased: {
      root.barMovePressed = false
      if (root.barMoveActive) {
        root.barMoveClickSuppressed = true
        root.finishBarMove()
      }
    }
    onCanceled: {
      root.barMovePressed = false
      root.barMoveClickSuppressed = false
      root.cancelBarMove()
    }
  }

  HoverHandler {
    target: centerPeekArea
    onHoveredChanged: root.setCenterSectionReveal(hovered)
  }

  Item {
    id: centerPeekArea
    x: 0
    y: 0
    width: root.vertical ? Constants.barHeight : Math.max(0, centerSection.x)
    height: root.vertical ? Math.max(0, centerSection.y) : Constants.barHeight
  }

  function mapSectionCoordinate(section, coordinate) {
    var point = root.vertical
      ? root.contentItem.mapFromItem(section, 0, coordinate)
      : root.contentItem.mapFromItem(section, coordinate, 0)
    return root.vertical ? point.y : point.x
  }

  BarSection {
    id: leftSection

    sectionName: "left"
    bar: root
    ids: Config.bar.left
    screen: root.screen
    activeId: root.activeId
    x: root.vertical ? Math.round((parent.width - width) / 2) : root.sectionMargin
    y: root.vertical ? root.sectionMargin : Math.round((parent.height - height) / 2)

    onActivated: function(id, x) {
      root.widgetActivated(id, root.mapSectionCoordinate(leftSection, x))
    }

    onTooltipEntered: function(slot, text, x) { root.showTooltip(slot, text, x, leftSection) }
    onTooltipLeft: function(slot) { root.hideTooltip(slot) }
  }

  BarSection {
    id: centerBeginSection

    sectionName: "centerBegin"
    bar: root
    ids: Config.bar.centerBegin
    screen: root.screen
    activeId: root.activeId
    x: root.vertical ? centerSection.x : centerSection.x - width
    y: root.vertical ? centerSection.y - height : centerSection.y

    onActivated: function(id, x) {
      root.widgetActivated(id, root.mapSectionCoordinate(centerBeginSection, x))
    }

    onTooltipEntered: function(slot, text, x) { root.showTooltip(slot, text, x, centerBeginSection) }
    onTooltipLeft: function(slot) { root.hideTooltip(slot) }
  }

  BarSection {
    id: centerSection

    sectionName: "center"
    bar: root
    ids: Config.bar.center
    screen: root.screen
    activeId: root.activeId
    x: root.vertical ? Math.round((parent.width - width) / 2) : Math.round((parent.width - width) / 2)
    y: root.vertical ? Math.round((parent.height - height) / 2) : Math.round((parent.height - height) / 2)

    onActivated: function(id, x) {
      root.widgetActivated(id, root.mapSectionCoordinate(centerSection, x))
    }

    onTooltipEntered: function(slot, text, x) { root.showTooltip(slot, text, x, centerSection) }
    onTooltipLeft: function(slot) { root.hideTooltip(slot) }
  }

  BarSection {
    id: centerEndSection

    sectionName: "centerEnd"
    bar: root
    ids: Config.bar.centerEnd
    screen: root.screen
    activeId: root.activeId
    x: root.vertical ? centerSection.x : centerSection.x + centerSection.width
    y: root.vertical ? centerSection.y + centerSection.height : centerSection.y

    onActivated: function(id, x) {
      root.widgetActivated(id, root.mapSectionCoordinate(centerEndSection, x))
    }

    onTooltipEntered: function(slot, text, x) { root.showTooltip(slot, text, x, centerEndSection) }
    onTooltipLeft: function(slot) { root.hideTooltip(slot) }
  }

  BarSection {
    id: rightSection

    sectionName: "right"
    bar: root
    ids: Config.bar.right
    screen: root.screen
    activeId: root.activeId
    x: root.vertical ? Math.round((parent.width - width) / 2) : parent.width - root.sectionMargin - width
    y: root.vertical ? parent.height - root.sectionMargin - height : Math.round((parent.height - height) / 2)

    onActivated: function(id, x) {
      root.widgetActivated(id, root.mapSectionCoordinate(rightSection, x))
    }

    onTooltipEntered: function(slot, text, x) { root.showTooltip(slot, text, x, rightSection) }
    onTooltipLeft: function(slot) { root.hideTooltip(slot) }
  }

  // The room the drag has opened: the same foreground outline and faint
  // widget copy Omarchy's RoomOutline/DragSpacer draw, not an accent slab.
  Item {
    id: dragRoomOutline

    readonly property real length: root.roomLengthForDrop()

    visible: root.widgetDrag !== null && root.widgetDrop !== null && !root.widgetRemoveArmed && length > 0
    x: root.vertical ? 0 : Math.round(root.widgetDrop ? root.widgetDrop.position : 0)
    y: root.vertical ? Math.round(root.widgetDrop ? root.widgetDrop.position : 0) : 0
    width: root.vertical ? Constants.barHeight : length
    height: root.vertical ? length : Constants.barHeight
    clip: true
    z: 100

    Rectangle {
      anchors.fill: parent
      anchors.margins: 1
      color: Colors.background
      border.width: 1
      border.color: Colors.foreground
      radius: Math.min(Constants.cornerRadius, Math.min(width, height) / 2)
      opacity: 0.32
    }

    Image {
      anchors.centerIn: parent
      width: root.widgetDragWidth
      height: root.widgetDragHeight
      source: root.widgetDragImage
      fillMode: Image.Stretch
      smooth: true
      opacity: 0.22
    }
  }

  PanelWindow {
    id: dragOverlay
    screen: root.screen
    visible: root.widgetDrag !== null || root.barMoveActive
    anchors.top: true
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "omashell-bar-drag"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Repeater {
      model: ["top", "bottom", "left", "right"]
      Rectangle {
        required property string modelData
        visible: opacity > 0
        x: modelData === "right" ? parent.width - width : 0
        y: modelData === "bottom" ? parent.height - height : 0
        width: modelData === "left" || modelData === "right" ? Constants.barHeight : parent.width
        height: modelData === "top" || modelData === "bottom" ? Constants.barHeight : parent.height
        color: Colors.background
        border.width: 1
        border.color: Colors.foreground
        opacity: root.barMoveActive && root.barMoveCandidate === modelData ? 0.7 : 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      }
    }

    Item {
      visible: root.widgetDrag !== null
      readonly property var pointer: root.screenPoint(root.widgetDragX, root.widgetDragY)
      readonly property var settle: root.widgetSettle
      x: settle
        ? (settle.fromX + (settle.toX - settle.fromX) * root.widgetSettleProgress)
        : pointer.x - root.widgetDragOffsetX
      y: settle
        ? (settle.fromY + (settle.toY - settle.fromY) * root.widgetSettleProgress)
        : pointer.y - root.widgetDragOffsetY
      width: root.widgetDragWidth
      height: root.widgetDragHeight
      opacity: root.widgetRemoveArmed ? 0.55 : 1
      scale: root.widgetRemoveArmed ? 0.82 : 1
      transformOrigin: Item.Center

      Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

      // RoomOutline: inset one pixel, background fill, one-pixel foreground
      // border, as the ghost of a widget is drawn in Omarchy.
      Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        color: Colors.background
        border.width: 1
        border.color: Colors.foreground
        radius: Math.min(Constants.cornerRadius, Math.min(width, height) / 2)
        opacity: 0.94
      }

      Image {
        anchors.fill: parent
        source: root.widgetDragImage
        fillMode: Image.Stretch
        smooth: true
        opacity: 0.84
      }
    }
  }
}
