import QtQuick
import QtQuick.Effects
import Quickshell
import qs.common
import qs.config
import qs.modules.notifications
import 'Model.js' as Model

Item {
  id: root

  property var row: ({})
  property var place: ({ y: 0, scale: 1, opacity: 1, z: 1, front: true, hidden: false })
  property bool expanded: false
  property bool sole: false
  property bool hovered: false
  property bool keyboardSelected: false
  property string copiedCode: ''
  property real cardWidth: 380

  readonly property int border: 2
  readonly property bool critical: Number(row.urgency) === 2
  readonly property color dimColor: Qt.darker(Colors.foreground, 1.4)
  readonly property color bodyColor: Qt.darker(Colors.foreground, 1.15)
  readonly property color accentColor: critical ? Colors.red
    : (Number(row.urgency) === 0 ? dimColor : Colors.accent)
  readonly property bool hasBody: String(row.body || '') !== ''
  readonly property bool anonymous: String(row.app || '') === 'notify-send'
  readonly property bool glyphLed: summaryStartsWithGlyph(String(row.summary || ''))
  readonly property real contentPaddingY: hasBody ? 10 : 7
  readonly property var actions: row.actions && typeof row.actions.length === 'number' ? row.actions : []
  readonly property bool bodyOpen: expanded || (hovered && sole)
  readonly property int bodyLines: bodyOpen ? 8 : 2
  readonly property int fade: 150
  readonly property real contentOpacity: expanded || place.front ? 1 : 0
  readonly property bool buttonsShown: allDeeds.length > 0 && (expanded ? (hovered || keyboardSelected) : place.front)

  function summaryStartsWithGlyph(summary) {
    var text = summary.replace(/^\s+/, '')
    if (!text) return false
    var offset = 1
    var first = text.charCodeAt(0)
    if (first >= 0xd800 && first <= 0xdbff && text.length > 1) offset = 2
    var spaces = 0
    while (offset < text.length && text.charAt(offset) === ' ') {
      spaces++
      offset++
    }
    return spaces >= 2
  }

  readonly property string iconName: String(row.appIcon || '').replace(/^image:\/\/icon\//, '')
  readonly property string slugName: Model.slug(String(row.app || ''))
  property int iconFallback: 0
  readonly property var iconOptions: {
    var names = [iconName, slugName]
    var out = []
    for (var i = 0; i < names.length; i++) {
      var name = String(names[i] || '')
      if (!name) continue
      var found = name.charAt(0) === '/' ? Model.safeImage(name) : Quickshell.iconPath(name, true)
      if (found && out.indexOf(found) < 0) out.push(found)
    }
    return out
  }
  readonly property string iconSource: String(iconOptions[iconFallback] || '')
  onRowChanged: iconFallback = 0
  readonly property bool senderPictured: String(row.image || '') !== '' && senderImage.status === Image.Ready
  readonly property bool pictured: senderPictured || (iconSource !== '' && iconLoader.status === Image.Ready)
  readonly property bool glyphed: !senderPictured && !pictured && String(row.glyph || '') !== ''
  readonly property bool lettered: !senderPictured && !pictured && !glyphed && !anonymous && !glyphLed
  readonly property bool mono: !senderPictured && (/-symbolic/.test(iconSource) || iconSource.indexOf('/symbolic/') >= 0)
  readonly property var allDeeds: {
    var deeds = []
    var codes = row.codes || []
    for (var c = 0; c < codes.length; c++) deeds.push({ kind: 'code', id: String(codes[c]), value: String(codes[c]), text: codes.length > 1 ? 'Copy ' + codes[c] : 'Copy code' })
    var commands = row.execActions || []
    for (var e = 0; e < commands.length; e++) deeds.push({ kind: 'exec', id: String(e), argv: commands[e].argv, text: String(commands[e].label || '') })
    for (var a = 0; a < actions.length; a++) deeds.push({ kind: 'action', id: String(actions[a].id), text: String(actions[a].text || '') })
    return deeds
  }

  readonly property real thumbSlot: 40
  readonly property real deedSegment: 34
  readonly property int deedColumns: Math.max(1, Math.min(3, allDeeds.length))
  readonly property int deedRows: Math.ceil(allDeeds.length / deedColumns)
  readonly property real deedHeight: buttonsShown ? deedRows * (1 + deedSegment) : 0

  readonly property real restingBody: Math.ceil(Math.max(1, metrics.height) * 2)
  readonly property real textBlock: headline.height + (hasBody ? column.spacing + bodyBox.height : 0)
  readonly property real restingBlock: headline.height + (hasBody ? column.spacing + restingBody : 0)
  readonly property real textOffset: Math.max(0, (thumbHeight - restingBlock) / 2)
  readonly property real thumbHeight: pictured || lettered || glyphed ? thumbSlot : 0
  readonly property real fixedHeight: border * 2 + contentPaddingY * 2 + Math.max(thumbHeight, textOffset + textBlock)
  readonly property real targetHeight: fixedHeight + deedHeight

  width: cardWidth
  height: targetHeight
  y: Number(place.y) || 0
  z: Number(place.z) || 1
  scale: Number(place.scale) || 1
  opacity: place.hidden ? 0 : Number(place.opacity === undefined ? 1 : place.opacity)
  transformOrigin: Item.Top
  enabled: !place.hidden

  Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
  Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
  Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
  Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

  signal dismissed()
  signal activated()

  function doDeed(deed) {
    if (deed.kind === 'code') {
      copiedCode = String(deed.value)
      copiedTimer.restart()
    }
    NotificationService.invokeDeed(row, deed)
  }

  Rectangle {
    id: plate
    width: parent.width
    height: parent.height
    radius: Constants.cornerRadius
    color: Colors.background
    border.width: root.border
    border.color: Colors.accent
  }

  Rectangle {
    anchors.fill: plate
    anchors.margins: root.border
    visible: root.keyboardSelected
    color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.08)
  }

  Row {
    id: layout
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.top: parent.top
    anchors.leftMargin: root.border + 12
    anchors.rightMargin: root.border + 12
    anchors.topMargin: root.border + root.contentPaddingY
    spacing: 12
    opacity: root.contentOpacity
    Behavior on opacity { NumberAnimation { duration: root.fade; easing.type: Easing.OutCubic } }

    Item {
      id: thumb
      width: root.thumbHeight > 0 ? root.thumbSlot : 0
      height: width
      visible: width > 0
      y: Math.max(0, (root.restingBlock - height) / 2)

      Rectangle {
        anchors.fill: parent
        visible: root.lettered
        radius: Constants.cornerRadius
        color: root.critical
          ? Qt.rgba(Colors.red.r, Colors.red.g, Colors.red.b, 0.12)
          : Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.04)
        Text {
          anchors.centerIn: parent
          text: String(root.row.app || '?').substring(0, 1).toUpperCase()
          color: root.dimColor
          font.family: Constants.fontFamily
          font.pixelSize: Constants.fontBody
          font.weight: Font.DemiBold
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
        }
      }

      Text {
        anchors.centerIn: parent
        visible: root.glyphed
        text: String(root.row.glyph || '')
        color: Colors.foreground
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontTitle
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
      }

      Image {
        id: senderImage
        anchors.fill: parent
        visible: root.senderPictured
        source: String(root.row.image || '')
        sourceSize.width: 96
        sourceSize.height: 96
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: false
        readonly property bool rounded: Constants.cornerRadius > 0
        layer.enabled: visible && rounded
        layer.effect: MultiEffect {
          maskEnabled: senderImage.rounded
          maskSource: senderMask
        }
      }

      Rectangle {
        id: senderMask
        anchors.fill: parent
        visible: false
        layer.enabled: true
        radius: Constants.cornerRadius
        color: 'black'
      }

      Image {
        id: iconLoader
        anchors.fill: parent
        visible: !root.senderPictured && root.pictured
        source: root.iconSource
        sourceSize.width: 96
        sourceSize.height: 96
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        opacity: root.mono ? 0.85 : 1
        layer.enabled: visible && root.mono
        layer.effect: MultiEffect {
          colorization: 1
          colorizationColor: Colors.foreground
        }
        onStatusChanged: if (status === Image.Error && root.iconFallback < root.iconOptions.length) root.iconFallback += 1
      }
    }

    Column {
      id: column
      y: root.textOffset
      width: layout.width - (thumb.visible ? thumb.width + layout.spacing : 0)
      spacing: 3

      Item {
        id: headline
        width: parent.width
        height: Math.max(title.implicitHeight, rightSide.height)

        Text {
          id: title
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          width: Math.max(1, parent.width - rightSide.width - 8)
          text: String(root.row.summary || '')
          color: Colors.foreground
          font.family: 'Liberation Sans'
          font.pixelSize: Constants.fontTitle
          font.bold: true
          wrapMode: Text.Wrap
          maximumLineCount: root.bodyOpen ? 8 : 3
          elide: Text.ElideRight
          textFormat: Text.PlainText
        }

        Row {
          id: rightSide
          anchors.right: parent.right
          anchors.verticalCenter: title.verticalCenter
          spacing: 5

          Item {
            width: Math.max(stamp.implicitWidth, shut.implicitWidth)
            height: Math.max(stamp.implicitHeight, shut.implicitHeight)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              id: stamp
              anchors.centerIn: parent
              text: Model.ago(Number(root.row.time || 0), NotificationService.nowTick)
              color: root.dimColor
              opacity: root.hovered ? 0 : 1
              visible: opacity > 0.01
              font.family: Constants.fontFamily
              font.pixelSize: Constants.fontBodySmall
              textFormat: Text.PlainText
              renderType: Text.NativeRendering
              Behavior on opacity { NumberAnimation { duration: root.fade; easing.type: Easing.InOutQuad } }
            }

            Item {
              id: shut
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              implicitWidth: closeMark.implicitWidth + 6
              implicitHeight: closeMark.implicitHeight
              enabled: root.hovered
              opacity: root.hovered ? 1 : 0
              visible: opacity > 0.01
              Behavior on opacity { NumberAnimation { duration: root.fade; easing.type: Easing.InOutQuad } }

              Text {
                id: closeMark
                anchors.centerIn: parent
                text: '✕'
                color: shutMouse.containsMouse ? Colors.foreground : root.dimColor
                font.family: Constants.fontFamily
                font.pixelSize: Math.round(Constants.fontCaption * 1.44)
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
              }

              MouseArea {
                id: shutMouse
                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.dismissed()
              }
            }
          }
        }
      }

      FontMetrics {
        id: metrics
        font.family: 'Liberation Sans'
        font.pixelSize: Constants.fontTitle
      }

      Text {
        id: bodyBox
        width: parent.width
        visible: root.hasBody
        textFormat: Text.StyledText
        text: String(root.row.html || '')
        color: root.bodyColor
        linkColor: Colors.accent
        font.family: 'Liberation Sans'
        font.pixelSize: Constants.fontTitle
        wrapMode: Text.Wrap
        maximumLineCount: root.bodyLines
        elide: Text.ElideRight
        onLinkActivated: function(url) { Qt.openUrlExternally(url) }
      }
    }
  }

  Timer {
    id: copiedTimer
    interval: 1400
    onTriggered: root.copiedCode = ''
  }

  Item {
    id: deedArea
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: parent.bottom
    anchors.leftMargin: root.border
    anchors.rightMargin: root.border
    anchors.bottomMargin: root.border
    height: root.deedHeight
    visible: height > 0
    clip: true

    Item {
      id: deedRow
      anchors.bottom: parent.bottom
      width: parent.width
      height: parent.height
      opacity: 1

      Repeater {
        model: root.allDeeds
        delegate: DeedButton {
          required property var modelData
          required property int index
          readonly property int line: Math.floor(index / root.deedColumns)
          readonly property int slot: index % root.deedColumns
          readonly property int perLine: line < root.deedRows - 1 ? root.deedColumns
            : root.allDeeds.length - line * root.deedColumns
          readonly property real start: Math.round(slot * deedRow.width / perLine)
          deed: modelData
          taken: modelData.kind === 'code' && root.copiedCode === String(modelData.value)
          hint: root.keyboardSelected && index < 9 ? String(index + 1) : ''
          ruleColor: Qt.rgba(root.dimColor.r, root.dimColor.g, root.dimColor.b, 0.35)
          leftRule: slot > 0
          width: Math.round((slot + 1) * deedRow.width / perLine) - start
          x: start
          y: line * (1 + root.deedSegment)
          height: 1 + root.deedSegment
          onActivated: root.doDeed(modelData)
        }
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    z: -1
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(event) {
      if (event.button === Qt.LeftButton) root.activated()
      else root.dismissed()
    }
  }

  HoverHandler {
    id: hover
    onHoveredChanged: root.hovered = hovered
  }
}
