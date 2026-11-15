import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.config
import qs.modules.notifications
import 'Model.js' as Model

Variants {
  id: deck

  model: Quickshell.screens

  readonly property string focusedName: Hyprland.focusedMonitor
    ? String(Hyprland.focusedMonitor.name)
    : (Quickshell.screens.length > 0 ? String(Quickshell.screens[0].name) : '')
  readonly property string targetName: NotificationService.deckScreen !== ''
    ? NotificationService.deckScreen
    : deck.focusedName
  readonly property int cardWidth: 380
  property var heights: ({})
  property int heightsRevision: 0
  property bool hoveredDeck: false
  property string hoveredKey: ''

  readonly property bool expandedDeck: hoveredDeck || NotificationService.keyboardMode
  readonly property string openGroup: {
    var key = NotificationService.keyboardMode ? NotificationService.keyboardKey : deck.hoveredKey
    var row = NotificationService.rowFor(key)
    return row ? Model.groupKey(row) : ''
  }
  readonly property var layout: Model.panelLayout(NotificationService.live, deck.expandedDeck, deck.heights,
    { gap: 6, deckGap: 12, openGroup: deck.openGroup })

  function setHeight(key, value) {
    if (Number(deck.heights[key]) === Number(value)) return
    var next = Object.assign({}, deck.heights)
    next[key] = Number(value)
    deck.heights = next
    deck.heightsRevision += 1
  }

  function pin() { NotificationService.deckScreen = deck.focusedName }
  function unpin() { if (NotificationService.live.length === 0) NotificationService.deckScreen = '' }
  onFocusedNameChanged: if (Quickshell.screens.length > 0 && NotificationService.live.length > 0) pin()

  Connections {
    target: NotificationService
    function onRevisionChanged() {
      if (NotificationService.live.length > 0) deck.pin()
      else deck.unpin()
    }
  }

  delegate: PanelWindow {
    id: surface

    required property var modelData

    screen: modelData
    visible: NotificationService.live.length > 0 && String(modelData.name) === deck.targetName
    color: 'transparent'
    exclusionMode: ExclusionMode.Ignore
    anchors.top: true
    anchors.bottom: true
    anchors.right: true
    implicitWidth: deck.cardWidth + Constants.gap * 2
    mask: Region { item: surface.visible ? clipper : null }

    WlrLayershell.namespace: 'omashell-notifications'
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: NotificationService.keyboardMode && String(modelData.name) === deck.targetName
      ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Item {
      id: clipper
      anchors.right: parent.right
      anchors.rightMargin: Constants.gap
      anchors.top: parent.top
      anchors.topMargin: Constants.barHeight + Constants.gap
      width: deck.cardWidth
      height: deck.layout.height
      clip: true

      Item {
        id: cardsHost
        width: parent.width
        height: deck.layout.height

        Repeater {
          model: NotificationService.live
          delegate: Toast {
            id: card
            required property var modelData

            readonly property var placement: deck.layout.placements[card.modelData.key] || ({ y: 0, scale: 1, opacity: 1, z: 1, front: true, hidden: false })

            width: deck.cardWidth
            row: card.modelData
            place: card.placement
            expanded: deck.expandedDeck && deck.openGroup === Model.groupKey(card.modelData)
            keyboardSelected: NotificationService.keyboardMode && String(card.modelData.key) === NotificationService.keyboardKey
            sole: NotificationService.live.length === 1
            onHoveredChanged: if (card.hovered) deck.hoveredKey = String(card.modelData.key)
            onTargetHeightChanged: deck.setHeight(card.modelData.key, card.targetHeight)
            onDismissed: NotificationService.dismiss(card.modelData)
            onActivated: NotificationService.activate(card.modelData)
          }
        }
      }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: NotificationService.keyboardMode && String(modelData.name) === deck.targetName
        Keys.onPressed: function(event) {
          if (NotificationService.keyboardPressed(event.key, event.text)) event.accepted = true
        }
      }

      MouseArea {
        id: deckHover
        z: 5000
        anchors.fill: cardsHost
        anchors.margins: -4
        hoverEnabled: true
        acceptedButtons: Qt.NoButton
        onContainsMouseChanged: {
          deck.hoveredDeck = containsMouse
          if (!containsMouse) deck.hoveredKey = ''
        }
      }
    }
  }
}
