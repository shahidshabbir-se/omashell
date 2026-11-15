import QtQuick
import qs.common
import qs.config
import qs.modules.notifications
import 'Model.js' as Model

PanelShell {
  id: root

  layerNamespace: 'omashell-notifications-panel'
  cardWidth: root.width > 0 ? Math.min(380, Math.max(120, root.width - Constants.gap * 2)) : 380
  keyboard: true
  focusTarget: nav
  signal switchPanelRequested(int direction)

  readonly property var rows: NotificationService.history
  readonly property string caption: NotificationService.dnd
    ? 'Do not disturb'
    : (rows.length === 0 ? 'Nothing saved' : rows.length + (rows.length === 1 ? ' saved notification' : ' saved notifications'))

  function resetNavigation() {
    nav.refresh()
    var target = 0
    for (var i = 0; i < nav.items.length; i++)
      if (nav.items[i].navigationKey === 'notifications-toggle') { target = i; break }
    nav.reset(target)
  }

  onOpenedChanged: if (root.opened) Qt.callLater(root.resetNavigation)
  Connections {
    target: NotificationService
    function onHistoryChanged() { Qt.callLater(nav.refresh) }
    function onDndChanged() { Qt.callLater(nav.refresh) }
  }

  Column {
    id: body
    width: parent.width
    spacing: 12

    PanelHeader {
      width: parent.width
      panelNav: nav
      icon: NotificationService.dnd ? '󰂛' : '󰂚'
      title: 'Notifications'
      captions: [root.caption]
      rotating: false
      switchVisible: true
      switchChecked: NotificationService.dnd
      switchNavigationKey: 'notifications-toggle'
      switchNavGroup: 'header'
      switchOnTooltip: 'Silence notifications'
      switchOffTooltip: 'Allow notifications'
      onSwitchToggled: NotificationService.toggleDnd()

      Button {
        visible: root.rows.length > 0
        text: 'Clear'
        navigationKey: 'notifications-clear'
        navGroup: 'header'
        panelNav: nav
        fontSize: Constants.fontBodySmall
        outlined: true
        onActivated: NotificationService.clear()
      }
    }

    PanelSeparator { width: parent.width; pixelRatio: root.devicePixelRatio }

    Text {
      visible: root.rows.length === 0
      width: parent.width
      text: NotificationService.dnd ? 'Notifications are silenced.' : 'No notifications yet.'
      color: Qt.darker(Colors.foreground, 1.5)
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontBodySmall
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      wrapMode: Text.WordWrap
    }

    Flickable {
      id: viewport
      width: parent.width
      height: Math.min(list.implicitHeight, 400)
      contentHeight: list.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: contentHeight > height
      visible: root.rows.length > 0

      Column {
        id: list
        width: viewport.width
        spacing: 2
        Repeater {
          model: root.rows
          delegate: Item {
            id: rowItem
            required property var modelData
            required property int index
            readonly property bool navigable: true
            property bool hasCursor: false
            property var panelNav: nav
            property string navigationKey: 'notifications-row-' + modelData.key
            width: list.width
            implicitHeight: Math.max(rowColumn.implicitHeight, 26) + 14

            function activate() {}
            function remove() { NotificationService.removeHistory(rowItem.index) }

            Rectangle {
              anchors.fill: parent
              color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b,
                rowItem.hasCursor ? 0.08 : (rowMouse.containsMouse ? 0.04 : 0))
              border.width: rowItem.hasCursor ? 1 : 0
              border.color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.25)
            }

            Row {
              id: rowInner
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: 8
              anchors.rightMargin: 8
              anchors.verticalCenter: parent.verticalCenter
              spacing: 10

              Text {
                width: 22
                horizontalAlignment: Text.AlignHCenter
                anchors.verticalCenter: parent.verticalCenter
                text: rowItem.modelData.urgency === 2 ? '󰀪' : '󰂚'
                color: rowItem.modelData.urgency === 2 ? Colors.red : Colors.darkForeground
                font.family: Constants.fontFamily
                font.pixelSize: Constants.fontTitle
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
              }

              Column {
                id: rowColumn
                width: Math.max(0, parent.width - 22 - timeText.width - 20)
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Text {
                  width: parent.width
                  text: (rowItem.modelData.app === '' ? '' : rowItem.modelData.app + ' · ') + (rowItem.modelData.summary || '')
                  color: Colors.foreground
                  font.family: Constants.fontFamily
                  font.pixelSize: Constants.fontBody
                  font.bold: true
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                }

                Text {
                  width: parent.width
                  visible: text !== ''
                  text: Model.oneLine(rowItem.modelData.body || '')
                  color: Qt.darker(Colors.foreground, 1.4)
                  font.family: Constants.fontFamily
                  font.pixelSize: Constants.fontBodySmall
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  renderType: Text.NativeRendering
                }
              }

              Text {
                id: timeText
                width: 54
                anchors.verticalCenter: parent.verticalCenter
                horizontalAlignment: Text.AlignRight
                text: Model.ago(Number(rowItem.modelData.time || 0), NotificationService.nowTick)
                color: Colors.darkForeground
                font.family: Constants.fontFamily
                font.pixelSize: Constants.fontCaption
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
              }
            }

            MouseArea {
              id: rowMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onEntered: if (rowItem.panelNav) rowItem.panelNav.select(rowItem)
              onClicked: function(event) {
                if (event.button === Qt.RightButton) rowItem.remove()
              }
            }
          }
        }
      }
    }
  }

  PanelNav {
    id: nav
    container: body
    onCanceled: root.close()
    onTabRequested: function(direction) { root.switchPanelRequested(direction) }
    onDeleteRequested: if (nav.current && typeof nav.current.remove === 'function') nav.current.remove()
    onTextRequested: function(text) {
      if (text === 'd' || text === 'D') NotificationService.toggleDnd()
      else if (text === 'c' || text === 'C') NotificationService.clear()
    }
  }
}
