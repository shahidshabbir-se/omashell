import QtQuick
import QtQuick.Controls as Controls
import qs.config
import qs.common
import qs.modules.bar.widgets.worldclock

PanelShell {
  id: root

  layerNamespace: "omashell-world-clock"
  property bool globeMode: false
  property bool inlineSearch: false
  property int peopleEditIndex: -1
  function startAdding() {
    inlineSearch = true
    globeView.beginInlineSearch()
    Qt.callLater(function() { if (root.inlineSearch) addInput.forceActiveFocus() })
  }
  function stopAdding() {
    inlineSearch = false
    globeView.resetSearch()
  }
  function addSearchCity(city) {
    if (!city) return
    WorldClockService.addCity(city)
    stopAdding()
  }
  property real globeTransition: globeMode ? 1 : 0
  property int globeTransitionDuration: 800
  Behavior on globeTransition { NumberAnimation { duration: root.duration(root.globeTransitionDuration); easing.type: Easing.OutQuart } }
  function setGlobeMode(enabled, slow) {
    globeTransitionDuration = (enabled ? 800 : 500) * (slow ? 3 : 1)
    if (enabled && inlineSearch) stopAdding()
    if (enabled) peopleEditIndex = -1
    if (!enabled) globeView.resetSearch()
    globeMode = enabled
  }
  cardWidth: Math.min(340, Math.max(240, width - Constants.gap * 2))
  spacing: globeMode ? 28 : 14
  keyboard: globeMode || inlineSearch || peopleEditIndex >= 0

  onOpenedChanged: {
    if (opened) { WorldClockService.loadSettings(); globeSpin.restart() }
    else { peopleEditIndex = -1; stopAdding(); setGlobeMode(false, false) }
  }

  function actionColor(alpha) {
    return Qt.rgba(
      Colors.background.r + (Colors.foreground.r - Colors.background.r) * alpha,
      Colors.background.g + (Colors.foreground.g - Colors.background.g) * alpha,
      Colors.background.b + (Colors.foreground.b - Colors.background.b) * alpha, 1)
  }

  function rowFill(offset, hovered) {
    var alpha = WorldClockService.phaseFill(offset) + (hovered ? 0.05 : 0)
    return Qt.rgba(
      Colors.background.r + (Colors.foreground.r - Colors.background.r) * alpha,
      Colors.background.g + (Colors.foreground.g - Colors.background.g) * alpha,
      Colors.background.b + (Colors.foreground.b - Colors.background.b) * alpha,
      1)
  }

  Column {
    width: parent.width
    spacing: 2

    ArcText {
      width: parent.width
      text: WorldClockService.caption
      rise: 6
      pixelSize: Constants.fontCaption
      fontFamily: Constants.fontFamily
      color: Qt.darker(Colors.foreground, 1.55)
    }

    Row {
      anchors.horizontalCenter: parent.horizontalCenter
      spacing: 9

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "World"
        textFormat: Text.PlainText
        color: Colors.foreground
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontTitle
        font.weight: Font.DemiBold
      }

      Item {
        id: heroIcon
        anchors.verticalCenter: parent.verticalCenter
        width: 31
        height: 31

        MiniGlobe {
          id: heroGlobe
          anchors.fill: parent
          color: Colors.foreground
          opacity: 1 - Math.min(1, root.globeTransition / 0.12)
          visible: opacity > 0
          bold: true
          showMarker: WorldClockService.homeLocation && WorldClockService.homeLocation.lat !== undefined
          markerLat: WorldClockService.homeLocation && WorldClockService.homeLocation.lat !== undefined ? WorldClockService.homeLocation.lat : 0
          markerLon: WorldClockService.homeLocation && WorldClockService.homeLocation.lon !== undefined ? WorldClockService.homeLocation.lon : 0
          markerColor: Colors.accent
        }
        Text {
          anchors.centerIn: parent
          text: "×"
          opacity: Math.max(0, Math.min(1, (root.globeTransition - 0.2) / 0.35))
          visible: opacity > 0
          color: heroMouse.containsMouse ? Colors.foreground : Colors.darkForeground
          font.family: Constants.fontFamily
          font.pixelSize: Math.round(heroIcon.width * 0.8)
        }
        MouseArea {
          id: heroMouse
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          hoverEnabled: true
          onClicked: function(mouse) { root.setGlobeMode(!root.globeMode, (mouse.modifiers & Qt.ShiftModifier) !== 0) }
        }
      }

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "Clock"
        textFormat: Text.PlainText
        color: Colors.foreground
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontTitle
        font.weight: Font.DemiBold
      }
    }
  }

  property NumberAnimation globeSpin: NumberAnimation {
    id: globeSpin
    target: heroGlobe
    property: "spin"
    from: heroGlobe.markerLon - 1080
    to: heroGlobe.markerLon
    duration: root.duration(1250)
    easing.type: Easing.OutQuart
  }

  Item {
    width: parent.width
    height: Math.round(globeView.implicitHeight * root.globeTransition)
    visible: root.globeMode || root.globeTransition > 0
    clip: true

    GlobeView {
      id: globeView
      width: parent.width
      opacity: Math.min(1, root.globeTransition / 0.12)
      scale: 0.1 + root.globeTransition * 0.9
      transformOrigin: Item.Top
      enabled: root.globeMode
      onDismissRequested: root.setGlobeMode(false, false)
      onCityAdded: root.setGlobeMode(false, false)
    }
  }

  Column {
    width: parent.width
    spacing: 6
    visible: !root.globeMode

    Repeater {
      model: WorldClockService.rows

      Rectangle {
        id: cityRow

        required property var modelData
        required property int index

        readonly property var offset: modelData.offset
        readonly property bool ready: offset !== undefined && offset !== null
        readonly property bool lit: WorldClockService.isLit(offset)

        width: parent.width
        height: 69 + (root.peopleEditIndex === index ? 23 : (modelData.people && modelData.people.length > 0 ? 20 : 0))
        radius: Constants.cornerRadius
        color: root.rowFill(offset, rowHover.hovered)

        HoverHandler { id: rowHover }
        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.RightButton
          onClicked: if (WorldClockService.cities.length > 1) WorldClockService.removeCity(cityRow.index)
        }
        Row {
          anchors.right: parent.right
          anchors.top: parent.top
          anchors.topMargin: -9
          anchors.rightMargin: -5
          spacing: 5
          z: 3
          visible: rowHover.hovered || peopleMouse.containsMouse || removeMouse.containsMouse
          Rectangle {
            width: 20; height: 20; radius: 10
            color: root.actionColor(peopleMouse.containsMouse ? 0.24 : 0.14)
            border.width: 1; border.color: root.actionColor(peopleMouse.containsMouse ? 0.65 : 0.35)
            Text { anchors.centerIn: parent; text: "\uDB80\uDC14"; color: peopleMouse.containsMouse ? Colors.foreground : Qt.darker(Colors.foreground, 1.55); font.family: Constants.fontFamily; font.pixelSize: Constants.fontCaption }
            MouseArea {
              id: peopleMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
              onClicked: { root.peopleEditIndex = cityRow.index; peopleInput.text = (cityRow.modelData.people || []).join(", "); Qt.callLater(function() { peopleInput.forceActiveFocus() }) }
              PanelToolTip { text: "Who's here"; visible: peopleMouse.containsMouse }
            }
          }
          Rectangle {
            visible: WorldClockService.cities.length > 1
            width: 20; height: 20; radius: 10
            color: root.actionColor(removeMouse.containsMouse ? 0.24 : 0.14)
            border.width: 1; border.color: root.actionColor(removeMouse.containsMouse ? 0.65 : 0.35)
            Text { anchors.centerIn: parent; text: "×"; color: removeMouse.containsMouse ? Colors.foreground : Qt.darker(Colors.foreground, 1.55); font.family: Constants.fontFamily; font.pixelSize: Constants.fontBodySmall }
            MouseArea { id: removeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: WorldClockService.removeCity(cityRow.index); PanelToolTip { text: "Remove"; visible: removeMouse.containsMouse } }
          }
        }

        Column {
          id: rowLabels

          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.right: timeBlock.left
          anchors.rightMargin: 10
          anchors.top: parent.top
          anchors.topMargin: 12
          spacing: 2

          Text {
            width: parent.width
            elide: Text.ElideRight
            text: modelData.label
            textFormat: Text.PlainText
            color: Colors.foreground
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontSubtitle
            font.weight: Font.DemiBold
          }

          Row {
            width: parent.width
            spacing: 6
            visible: root.peopleEditIndex !== cityRow.index && modelData.people && modelData.people.length > 0
            Row {
              id: avatars
              spacing: -3
              Repeater {
                model: (cityRow.modelData.people || []).slice(0, 4)
                Rectangle {
                  required property string modelData
                  width: Math.round(Constants.fontCaption * 1.45); height: width; radius: width / 2
                  color: root.actionColor(0.28)
                  border.width: 1; border.color: cityRow.color
                  Text {
                    anchors.centerIn: parent
                    text: parent.modelData.replace(/^@/, "").charAt(0).toUpperCase()
                    color: Colors.foreground; font.family: Constants.fontFamily
                    font.pixelSize: Math.round(parent.width * 0.55); font.weight: Font.DemiBold
                  }
                }
              }
            }
            Text {
              width: Math.max(0, parent.width - avatars.width - parent.spacing)
              anchors.verticalCenter: parent.verticalCenter
              text: cityRow.modelData.people ? cityRow.modelData.people.join(", ") : ""
              textFormat: Text.PlainText; elide: Text.ElideRight
              color: Qt.darker(Colors.foreground, 1.55); font.family: Constants.fontFamily; font.pixelSize: Constants.fontCaption
            }
          }
          Controls.TextField {
            id: peopleInput
            width: parent.width
            visible: root.peopleEditIndex === cityRow.index
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontCaption
            color: Colors.foreground
            placeholderText: "Names or @github handles, comma separated"
            placeholderTextColor: Qt.darker(Colors.foreground, 1.6)
            leftPadding: 11; rightPadding: 11
            topPadding: 4; bottomPadding: 4
            selectionColor: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.35)
            selectedTextColor: Colors.foreground
            background: Rectangle {
              radius: Constants.cornerRadius
              color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, peopleInput.activeFocus || peopleInput.hovered ? 0.08 : 0.04)
              border.width: 1
              border.color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, peopleInput.activeFocus || peopleInput.hovered ? 0.25 : 0.4)
            }
            onEditingFinished: if (root.peopleEditIndex === cityRow.index) { WorldClockService.setPeople(cityRow.index, text); root.peopleEditIndex = -1 }
            Keys.onEscapePressed: { root.peopleEditIndex = -1; focus = false }
          }
          Item {
            width: parent.width
            height: dateRow.height

            Row {
              id: dateRow
              spacing: 4
              opacity: rowHover.hovered ? 0 : 1
              visible: opacity > 0

              Behavior on opacity {
                NumberAnimation { duration: root.duration(110) }
              }

              Text {
                text: ready ? WorldClockService.dateAt(offset) : "\u2026"
                textFormat: Text.PlainText
                color: Qt.darker(Colors.foreground, 1.55)
                font.family: Constants.fontFamily
                font.pixelSize: Constants.fontCaption
              }

              Text {
                visible: ready && WorldClockService.dayLabel(offset) !== ""
                text: "\u00B7"
                textFormat: Text.PlainText
                color: Qt.darker(Colors.foreground, 2.1)
                font.family: Constants.fontFamily
                font.pixelSize: Constants.fontCaption
              }

              Text {
                visible: ready && WorldClockService.dayLabel(offset) !== ""
                text: ready ? WorldClockService.dayLabel(offset) : ""
                textFormat: Text.PlainText
                color: Qt.darker(Colors.foreground, 1.55)
                font.family: Constants.fontFamily
                font.pixelSize: Constants.fontCaption
              }
            }

            Text {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              text: WorldClockService.greeting(offset)
              opacity: rowHover.hovered ? 1 : 0
              visible: opacity > 0
              textFormat: Text.PlainText
              color: Colors.foreground
              font.family: Constants.fontFamily
              font.pixelSize: Constants.fontCaption

              Behavior on opacity {
                NumberAnimation { duration: root.duration(110) }
              }
            }
          }
        }

        Column {
          id: timeBlock

          width: 58
          anchors.right: parent.right
          anchors.rightMargin: 12
          anchors.verticalCenter: rowLabels.verticalCenter
          spacing: 1

          Text {
            anchors.right: parent.right
            text: ready ? WorldClockService.timeAt(offset) : "--:--"
            textFormat: Text.PlainText
            color: Colors.foreground
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontHeading
            font.weight: Font.DemiBold
          }

          Text {
            anchors.right: parent.right
            visible: ready
            text: modelData.abbr + " " + WorldClockService.offsetLabel(offset)
            textFormat: Text.PlainText
            color: Qt.darker(Colors.foreground, 2.1)
            font.family: Constants.fontFamily
            font.pixelSize: Constants.fontCaption
          }
        }

        Rectangle {
          anchors.left: parent.left
          anchors.leftMargin: 12
          anchors.right: parent.right
          anchors.rightMargin: 12
          anchors.bottom: parent.bottom
          anchors.bottomMargin: 15
          height: 3
          radius: height / 2
          color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.10)

          Rectangle {
            x: parent.width * 0.25
            width: parent.width * 0.5
            height: parent.height
            radius: parent.radius
            color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.28)
          }

          Rectangle {
            x: Math.round(parent.width * WorldClockService.progressAt(offset) - 4)
            y: (parent.height - height) / 2
            width: 8
            height: 8
            radius: 4
            color: lit ? "#E5C736" : "transparent"
            border.width: lit ? 0 : 1
            border.color: Colors.foreground

            Behavior on x {
              NumberAnimation {
                duration: root.duration(400)
                easing.type: Easing.OutCubic
              }
            }
          }
        }
      }
    }
    Column {
      width: parent.width
      spacing: 6
      Button {
        width: parent.width
        height: 28
        visible: !root.inlineSearch
        text: "+ Add city"
        outlined: true
        onActivated: root.startAdding()
      }
      Rectangle {
        width: parent.width
        height: 28
        visible: root.inlineSearch
        color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.04)
        border.width: 1
        border.color: Colors.darkForeground
        TextInput {
          id: addInput
          anchors.fill: parent
          anchors.leftMargin: 10; anchors.rightMargin: 10
          verticalAlignment: TextInput.AlignVCenter
          color: Colors.foreground
          font.family: Constants.fontFamily; font.pixelSize: Constants.fontBodySmall
          clip: true
          onTextChanged: if (root.inlineSearch) globeView.searchText = text
          Text { anchors.verticalCenter: parent.verticalCenter; visible: addInput.text === ""; text: "Search cities..."; color: Colors.darkForeground; font: addInput.font }
          Keys.onEscapePressed: { text = ""; root.stopAdding() }
          Keys.onDownPressed: if (globeView.filtered.length) globeView.searchIndex = (globeView.searchIndex + 1) % globeView.filtered.length
          Keys.onUpPressed: if (globeView.filtered.length) globeView.searchIndex = (globeView.searchIndex + globeView.filtered.length - 1) % globeView.filtered.length
          Keys.onReturnPressed: if (globeView.filtered.length) { root.addSearchCity(globeView.filtered[globeView.searchIndex]); text = "" }
          Keys.onEnterPressed: if (globeView.filtered.length) { root.addSearchCity(globeView.filtered[globeView.searchIndex]); text = "" }
        }
      }
      Column {
        width: parent.width
        visible: root.inlineSearch
        spacing: 2
        Repeater {
          model: root.inlineSearch ? globeView.filtered : []
          Rectangle {
            required property var modelData
            required property int index
            width: parent.width; height: 28; radius: Constants.cornerRadius
            color: index === globeView.searchIndex ? Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.08) : "transparent"
            Text { anchors.left: parent.left; anchors.leftMargin: 10; anchors.right: addZone.left; anchors.rightMargin: 6; anchors.verticalCenter: parent.verticalCenter; text: modelData.label + (modelData.region ? "  " + modelData.region : ""); color: Colors.foreground; font.family: Constants.fontFamily; font.pixelSize: Constants.fontBodySmall; elide: Text.ElideRight }
            Text { id: addZone; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; text: modelData.zone + (globeView.searchOffset(modelData.zone) ? "  " + globeView.searchOffset(modelData.zone) : ""); color: Colors.darkForeground; font.family: Constants.fontFamily; font.pixelSize: Constants.fontCaption }
            MouseArea { anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onPositionChanged: globeView.searchIndex = index; onClicked: { root.addSearchCity(modelData); addInput.text = "" } }
          }
        }
        Text {
          width: parent.width
          visible: root.inlineSearch && globeView.filtered.length === 0
          horizontalAlignment: Text.AlignHCenter
          text: globeView.cities.length === 0 ? "Loading cities..." : (globeView.wantedQuery && globeView.placeCache[globeView.wantedQuery] === undefined ? "Searching places..." : "No matches")
          color: Colors.darkForeground; font.family: Constants.fontFamily; font.pixelSize: Constants.fontCaption
        }
      }
    }
  }
}
