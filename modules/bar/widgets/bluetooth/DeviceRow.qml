import QtQuick
import qs.common
import qs.config
import "Model.js" as Model

                                                                                
                                                                              
Item {
  id: root

  property var row: null
  property string pending: ""
  property bool navigable: true
  property bool hasCursor: false
  property bool actionFocused: false
  property var panelNav: null
  readonly property bool isDeviceRow: true
  readonly property string navigationKey: root.row ? "device:" + root.row.address : ""
  readonly property bool actionAvailable: !!root.row && (root.row.connected || root.row.paired)

  signal activated()
  signal forgetRequested()

  readonly property string action: Model.actionFor(row)
  readonly property string actionTooltip: Model.actionWord(root.action)
  readonly property string status: Model.statusText(row, pending)

  implicitHeight: Math.max(18, info.implicitHeight, 24) + Constants.deviceRowPaddingY

  function shade(alpha) {
    return Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, alpha)
  }

  function activate() {
    if (root.pending !== "") return
    if (root.actionFocused) root.forgetRequested()
    else root.activated()
  }

  function adjust(delta) {
    if (!root.actionAvailable) return
    if (delta > 0) root.actionFocused = true
    else if (delta < 0) root.actionFocused = false
  }

  function forget() {
    if (root.actionAvailable && root.pending === "") root.forgetRequested()
  }

  function clearAction() {
    root.actionFocused = false
  }

  Rectangle {
    anchors.fill: parent
    radius: Constants.cornerRadius
    color: root.hasCursor || mouse.containsMouse ? root.shade(0.08)
      : (root.row && root.row.connected ? root.shade(0.18) : "transparent")
    border.width: root.hasCursor || mouse.containsMouse ? 1 : 0
    border.color: root.shade(0.25)
  }

  OpticalGlyph {
    id: glyph

    anchors.left: parent.left
    anchors.leftMargin: 10
    anchors.verticalCenter: parent.verticalCenter
    width: 18
    height: 18
    text: root.row ? root.row.glyph : ""
    fontSize: Constants.fontHeading
    paintedSize: Constants.fontHeading
    color: root.pending !== "" ? Colors.darkForeground : Colors.foreground
  }

  Column {
    id: info
    anchors.left: glyph.right
    anchors.leftMargin: 10
    anchors.right: parent.right
    anchors.rightMargin: root.actionAvailable ? 38 : 10
    anchors.verticalCenter: parent.verticalCenter
    spacing: 1

                                                                                
                                                   
    Text {
      width: parent.width
      text: root.row ? root.row.label : ""
      color: root.pending !== "" ? Colors.darkForeground : Colors.foreground
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontBody
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
    }

    Text {
      width: parent.width
      visible: text !== ""
      text: root.status
      color: Colors.foreground
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontCaption
      textFormat: Text.PlainText
      renderType: Text.NativeRendering
      elide: Text.ElideRight
    }
  }

  MouseArea {
    id: mouse

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: {
      root.actionFocused = false
      if (root.panelNav) root.panelNav.select(root)
    }
    onClicked: root.activate()

    PanelToolTip {
      visible: mouse.containsMouse && !root.actionFocused
      text: root.actionTooltip
      fontFamily: Constants.fontFamily
    }
  }

  Rectangle {
    id: forgetButton
    visible: root.actionAvailable && (root.hasCursor || mouse.containsMouse || root.actionFocused)
    width: 24
    height: 24
    anchors.right: parent.right
    anchors.rightMargin: 8
    anchors.verticalCenter: parent.verticalCenter
    color: root.actionFocused ? root.shade(0.18) : "transparent"
    border.width: root.actionFocused ? 1 : 0
    border.color: root.shade(0.25)

    Text {
      anchors.centerIn: parent
      text: "\uDB80\uDD59"
      color: Colors.foreground
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontTitle
    }

    MouseArea {
      anchors.fill: parent
      hoverEnabled: true
      enabled: root.pending === ""
      cursorShape: Qt.PointingHandCursor
      onEntered: {
        if (root.panelNav) root.panelNav.select(root)
        root.actionFocused = true
      }
      onClicked: root.forgetRequested()

      PanelToolTip {
        visible: parent.containsMouse
        text: "Forget"
        fontFamily: Constants.fontFamily
      }
    }
  }
}
