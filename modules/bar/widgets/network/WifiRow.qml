import QtQuick
import qs.common
import qs.config
import "Model.js" as Model

                                                                              
                                                                              
                                                                        
Item {
  id: root

  property var row: null
  property var network: null
  property bool enterprise: false
  property bool credentialsRequired: false
  property string pendingKind: ""                                              
  property string failureReason: ""
  property bool passwordOpen: false
  property var panelNav: null
  property string navGroup: ""
  property bool navigable: true
  property bool hasCursor: false
  property bool actionFocused: false

  readonly property bool isWifiRow: true
  readonly property string navigationKey: root.row ? "wifi:" + root.row.ssid : ""
  readonly property string ssid: root.row ? root.row.ssid : ""
  readonly property bool isConnected: !!root.row && !!root.row.connected
  readonly property bool actionAvailable: !!root.row && !!root.row.known && !root.isConnected
  readonly property bool passwordVisible: root.passwordOpen && !root.isConnected
  readonly property bool forgetVisible: root.actionAvailable && (root.hasCursor || rowMouse.containsMouse || root.actionFocused)

  property string passwordText: ""
  property string identityText: ""

  signal activated()
  signal forgetRequested()
  signal credentialsSubmitted(string passphrase, string identity)
  signal passwordCanceled()

  readonly property string statusText: {
    if (!root.row) return ""
    if (root.passwordVisible) return ""
    if (root.pendingKind === "connect") return "Connecting…"
    if (root.pendingKind === "disconnect") return "Disconnecting…"
    if (root.pendingKind === "forget") return "Forgetting…"
    if (root.failureReason !== "") return root.failureReason
    if (root.isConnected) return "Connected"
    return ""
  }

  implicitHeight: body.implicitHeight + (root.passwordVisible ? passwordPanel.implicitHeight + 10 : 0)

  onPasswordOpenChanged: {
    if (!root.passwordOpen) {
      root.passwordText = ""
      root.identityText = ""
    } else {
      Qt.callLater(function() {
        if (root.passwordVisible) {
          if (root.enterprise) identityField.activate()
          else passwordField.activate()
        }
      })
    }
  }

  onFailureReasonChanged: if (root.passwordVisible && root.failureReason === "" && root.pendingKind === "")
    Qt.callLater(function() { if (root.passwordVisible) passwordField.activate() })

  function activate() {
    if (root.pendingKind !== "") return
    if (root.actionFocused && root.actionAvailable) {
      root.forgetRequested()
      return
    }
    if (root.passwordVisible) {
      if (root.failureReason !== "") { root.activated(); return }
      root.submitCredentials()
      return
    }
    root.activated()
  }

                                                                               
                              
  function adjust(delta) {
    if (!root.actionAvailable) return
    if (delta > 0) root.actionFocused = true
    else if (delta < 0) root.actionFocused = false
  }

  function forget() {
    if (root.actionAvailable && root.pendingKind === "") root.forgetRequested()
  }

  function clearAction() {
    root.actionFocused = false
  }

  function submitCredentials() {
    if (root.pendingKind !== "" || root.passwordText.length === 0) return
    if (root.enterprise && root.identityText.length === 0) return
    root.credentialsSubmitted(root.passwordText, root.identityText)
  }

  function shade(alpha) {
    return Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, alpha)
  }

  Rectangle {
    anchors.fill: parent
    radius: Constants.cornerRadius
    color: root.hasCursor || rowMouse.containsMouse ? root.shade(0.08)
      : (root.isConnected ? root.shade(0.18) : "transparent")
    border.width: root.hasCursor || rowMouse.containsMouse ? 1 : 0
    border.color: root.shade(0.25)
  }

  Item {
    id: body

    width: parent.width
    implicitHeight: Math.max(glyph.implicitHeight, info.implicitHeight, rightColumn.implicitHeight) + Constants.deviceRowPaddingY

    OpticalGlyph {
      id: glyph

      anchors.left: parent.left
      anchors.leftMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      width: 18
      height: 18
      fontSize: Constants.fontHeading
      paintedSize: Constants.fontHeading
      text: root.row ? Model.wifiIconFor(root.row.signal) : ""
      color: root.pendingKind !== "" ? Colors.darkForeground : Colors.foreground
    }

    Column {
      id: info

      anchors.left: glyph.right
      anchors.leftMargin: 10
      anchors.right: rightColumn.left
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      spacing: 1

      Text {
        width: parent.width
        text: root.ssid !== "" ? root.ssid : "Hidden network"
        color: root.pendingKind !== "" ? Colors.darkForeground : Colors.foreground
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontBody
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        elide: Text.ElideRight
      }

      Text {
        width: parent.width
        visible: text !== ""
        text: root.statusText
        color: root.failureReason !== "" ? Colors.red
          : (root.isConnected || root.pendingKind !== "" ? Colors.foreground : Qt.darker(Colors.foreground, 1.5))
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontCaption
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
        elide: Text.ElideRight
      }
    }

    Item {
      id: rightColumn

      anchors.right: parent.right
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      visible: root.credentialsRequired || root.actionAvailable
      width: 22
      implicitHeight: lockIndicator.implicitHeight

      Text {
        id: lockIndicator

        anchors.centerIn: parent
        visible: root.credentialsRequired && !root.forgetVisible
        text: "\u{f033e}"
        color: Qt.darker(Colors.foreground, 1.4)
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontSubtitle
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
      }

      Rectangle {
        id: forgetButton

        visible: root.forgetVisible
        width: 24
        height: 24
        anchors.centerIn: parent
        color: root.actionFocused ? root.shade(0.18) : "transparent"
        border.width: root.actionFocused ? 1 : 0
        border.color: root.shade(0.25)

        Text {
          anchors.centerIn: parent
          text: "\u{f0159}"
          color: Colors.red
          font.family: Constants.fontFamily
          font.pixelSize: Constants.fontSubtitle
          textFormat: Text.PlainText
          renderType: Text.NativeRendering
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          enabled: root.pendingKind === ""
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
  }

  Item {
    id: passwordPanel

    anchors.top: body.bottom
    anchors.topMargin: 4
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: 10
    anchors.rightMargin: 10
    visible: root.passwordVisible
    implicitHeight: (root.enterprise ? identityField.implicitHeight + 4 : 0)
      + passwordField.implicitHeight + 8
    height: implicitHeight

    Field {
      id: identityField
      anchors.left: parent.left
      anchors.right: connectButton.left
      anchors.rightMargin: 6
      anchors.top: parent.top
      visible: root.enterprise && root.pendingKind === "" && root.failureReason === ""
      placeholder: "Identity"
      onTextChanged: root.identityText = text
      onSubmitted: passwordField.activate()
      onCanceled: root.passwordCanceled()
    }

    Field {
      id: passwordField
      anchors.left: parent.left
      anchors.right: connectButton.left
      anchors.rightMargin: 6
      anchors.bottom: parent.bottom
      anchors.bottomMargin: 4
      visible: root.pendingKind === "" && root.failureReason === ""
      password: true
      placeholder: "Passphrase"
      onTextChanged: root.passwordText = text
      onSubmitted: root.submitCredentials()
      onCanceled: root.passwordCanceled()
    }

    Rectangle {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      height: 28
      visible: root.pendingKind !== "" || root.failureReason !== ""
      color: root.shade(0.04)
      border.width: 1
      border.color: root.shade(0.4)
      Text {
        anchors.centerIn: parent
        text: root.failureReason !== "" ? root.failureReason : "Connecting…"
        color: root.failureReason !== "" ? Colors.red : Colors.foreground
        font.family: Constants.fontFamily
        font.pixelSize: Constants.fontBodySmall
        textFormat: Text.PlainText
      }
    }

    ActionIcon {
      id: connectButton
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      width: 22
      height: 22
      visible: root.pendingKind === "" && root.failureReason === ""
      enabled: root.passwordText.length > 0 && (!root.enterprise || root.identityText.length > 0)
      glyph: "󰄬"
      tooltipText: "Connect"
      onActivated: root.submitCredentials()
    }
  }

  MouseArea {
    id: rowMouse

    z: -1
    anchors.fill: body
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onEntered: {
      root.actionFocused = false
      if (root.panelNav) root.panelNav.select(root)
    }
    onClicked: root.activate()

    PanelToolTip {
      visible: rowMouse.containsMouse && !root.actionFocused && root.statusText === "" && !root.passwordVisible
      text: root.isConnected ? "Disconnect" : "Connect"
      fontFamily: Constants.fontFamily
    }
  }
}
