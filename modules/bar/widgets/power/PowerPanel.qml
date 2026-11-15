import QtQuick
import qs.common
import qs.config
import qs.modules.bar.widgets.power

PanelShell {
  id: root
  layerNamespace: 'omashell-power'
  cardWidth: root.width > 0 ? Math.min(380, Math.max(120, root.width - Constants.gap * 2)) : 380
  keyboard: true
  focusTarget: nav
  signal switchPanelRequested(int direction)

  property int phraseIndex: 0
  readonly property var phrases: PowerService.discharging
    ? ['Using battery', 'Powering along', 'Running unplugged', 'Drawing energy']
    : ['Charging up', 'Storing energy', 'Filling the battery', 'Powering up']
  readonly property string status: PowerService.full || PowerService.threshold ? PowerService.mode : phrases[phraseIndex % phrases.length]

  onOpenedChanged: {
    if (opened) {
      if (!PowerService.present) { Qt.callLater(function() { root.close() }); return }
      PowerService.refresh()
      Qt.callLater(function() {
        nav.refresh()
        var index = PowerService.profiles.indexOf(PowerService.activeProfile)
        nav.reset(index >= 0 ? index : 0)
      })
    }
  }
  Connections {
    target: PowerService
    function onPresentChanged() { if (!PowerService.present) root.close() }
    function onProfilesChanged() {
      Qt.callLater(function() {
        nav.refresh()
        if (!nav.cursorActive) {
          var index = PowerService.profiles.indexOf(PowerService.activeProfile)
          nav.reset(index >= 0 ? index : 0)
        }
      })
    }
  }
  Timer { interval: 5000; running: root.opened; repeat: true; onTriggered: PowerService.refresh() }
  Timer {
    interval: 2800
    running: root.opened && !PowerService.full && !PowerService.threshold
    repeat: true
    onTriggered: phraseAnimation.restart()
  }
  SequentialAnimation {
    id: phraseAnimation
    NumberAnimation { target: heroStatus; property: 'opacity'; to: 0; duration: 150; easing.type: Easing.OutCubic }
    ScriptAction { script: root.phraseIndex++ }
    NumberAnimation { target: heroStatus; property: 'opacity'; to: 1; duration: 200; easing.type: Easing.OutCubic }
  }

  Column {
    id: body
    width: parent.width
    spacing: 14

    Item {
      width: parent.width
      implicitHeight: Math.max(heroIcon.implicitHeight, labels.implicitHeight, percent.implicitHeight)
      Text {
        id: heroIcon
        text: PowerService.icon
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontDisplay
        color: Colors.foreground
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
      }
      Column {
        id: labels
        anchors.left: heroIcon.right
        anchors.leftMargin: 14
        anchors.right: percent.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
          text: 'Battery'
          width: parent.width
          elide: Text.ElideRight
          color: Colors.foreground
          font.family: Constants.fontFamily
          font.pixelSize: Constants.fontTitle
          font.bold: true
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
        }
        Text {
          id: heroStatus
          text: root.status.toUpperCase()
          width: parent.width
          elide: Text.ElideRight
          color: Qt.darker(Colors.foreground, 1.4)
          font.family: Constants.fontFamily
          font.pixelSize: Constants.fontCaption
          font.bold: true
          font.letterSpacing: 1.2
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
        }
      }
      Text {
        id: percent
        text: Math.round(PowerService.fraction * 100) + '%'
        font.family: Constants.fontFamily
        font.pixelSize: 28
        font.bold: true
        color: Colors.foreground
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
      }
    }
    Item {
      width: parent.width
      height: 8
      Rectangle { anchors.fill: parent; radius: Math.min(Constants.cornerRadius, height / 2); color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.12) }
      Rectangle {
        height: parent.height
        width: Math.max(height, parent.width * PowerService.fraction)
        radius: Math.min(Constants.cornerRadius, height / 2)
        color: Colors.foreground
        Behavior on width { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }
        SequentialAnimation on opacity {
          running: root.opened && PowerService.charging && !root.reduceMotion
          loops: Animation.Infinite
          NumberAnimation { from: 1; to: 0.55; duration: 950; easing.type: Easing.InOutSine }
          NumberAnimation { from: 0.55; to: 1; duration: 950; easing.type: Easing.InOutSine }
        }
      }
    }
    Row {
      visible: PowerService.battery.size !== undefined
      width: parent.width
      spacing: 20
      Column {
        width: (parent.width - parent.spacing) / 2
        spacing: 4
        InfoPair { label: 'Battery size'; value: PowerService.battery.size || '—' }
        InfoPair { label: 'Charge cycles'; value: PowerService.battery.cycles || '—' }
      }
      Column {
        width: (parent.width - parent.spacing) / 2
        spacing: 4
        InfoPair {
          label: PowerService.threshold ? 'Charge limit' : PowerService.discharging ? 'Time left' : 'Time to full'
          value: PowerService.threshold ? (PowerService.battery.threshold || '—') : PowerService.full ? '—' : (PowerService.battery.time || '—')
        }
        InfoPair {
          label: PowerService.threshold ? 'Battery state' : PowerService.discharging ? 'Discharging' : 'Charging'
          value: PowerService.threshold ? 'Holding' : PowerService.full ? '—' : (PowerService.battery.rate || '—')
        }
      }
    }
    PanelSeparator { width: parent.width; pixelRatio: root.devicePixelRatio }
    Column {
      width: parent.width
      spacing: 10
      SectionLabel { width: parent.width; text: 'Power profile' }
      Row {
        id: profileRow
        width: parent.width
        spacing: 6
        Repeater {
          model: PowerService.profiles
          ProfileButton {
            required property string modelData
            width: (profileRow.width - profileRow.spacing * Math.max(0, PowerService.profiles.length - 1)) / Math.max(1, PowerService.profiles.length)
            profile: modelData
            selected: PowerService.activeProfile === modelData
            panelNav: nav
            onActivated: PowerService.setProfile(profile)
          }
        }
      }
      Text {
        visible: PowerService.profiles.length === 0 || PowerService.error !== ''
        width: parent.width
        text: PowerService.error || 'Power profiles unavailable'
        color: Qt.darker(Colors.foreground, 1.4)
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontBodySmall
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
      }
    }
  }
  PanelNav {
    id: nav
    container: body
    customNavigation: true
    onCanceled: root.close()
    onTabRequested: function(direction) { root.switchPanelRequested(direction) }
    onMoveRequested: function(dx, dy) {
      if (!nav.cursorActive) { nav.cursorActive = true; return }
      nav.setIndex(nav.index + (dx !== 0 ? dx : dy))
    }
  }
  component InfoPair: Item {
    property string label: ''
    property string value: ''
    width: parent.width
    implicitHeight: Math.max(leftText.implicitHeight, rightText.implicitHeight)
    Text {
      id: leftText
      text: parent.label
      anchors.left: parent.left
      anchors.right: rightText.left
      anchors.rightMargin: 8
      elide: Text.ElideRight
      opacity: 0.6
      color: Colors.foreground
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontBodySmall
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
    }
    Text {
      id: rightText
      text: parent.value
      anchors.right: parent.right
      color: Colors.foreground
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontBodySmall
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
    }
  }
}
