pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../../../../config"
import "Model.js" as Model

PanelWindow {
    id: root

    property var targetScreen: null
    property bool open: false
    signal closeRequested

    property string iface: ""
    property string ssid: ""
    property bool secured: false
    property var qrRows: []
    property int qrSize: 0
    property string error: ""
    property bool loading: false
    property string password: ""
    property bool passwordVisible: false
    property string passwordError: ""
    property bool expectedStop: false

    readonly property bool showingQr: qrSize > 0 && !loading && error === ""
    readonly property string qrScript: Quickshell.shellPath("modules/bar/components/network/scripts/qs-network-qr")
    readonly property string pwScript: Quickshell.shellPath("modules/bar/components/network/scripts/qs-network-password")

    screen: targetScreen
    visible: open
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: open ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    function openWith(payload) {
        var p = payload || {}
        root.ssid = p.ssid ? String(p.ssid) : ""
        generate(p.iface ? String(p.iface) : "")
    }

    function close() {
        expectedStop = true
        qrProc.running = false
        pwProc.running = false
        loading = false
        error = ""
        qrSize = 0
        qrRows = []
        password = ""
        passwordVisible = false
        passwordError = ""
        root.closeRequested()
    }

    function generate(requestedIface) {
        expectedStop = false
        loading = true
        error = ""
        qrSize = 0
        qrRows = []
        password = ""
        passwordVisible = false
        passwordError = ""
        if (requestedIface) {
            root.iface = requestedIface
            qrProc.command = [root.qrScript, "--meta", requestedIface]
        } else {
            qrProc.command = [root.qrScript, "--meta"]
        }
        qrProc.running = true
    }

    function togglePassword() {
        if (passwordVisible) {
            passwordVisible = false
            return
        }
        if (password !== "") {
            passwordVisible = true
            return
        }
        if (pwProc.running || !iface) return
        passwordError = ""
        pwProc.command = [root.pwScript, iface]
        pwProc.running = true
    }

    function updateQr(raw) {
        var parsed = Model.parseQrOutput(raw)
        qrRows = parsed.matrix.rows
        qrSize = parsed.matrix.size
        if (parsed.meta.ssid !== "") root.ssid = parsed.meta.ssid
        if (parsed.meta.iface !== "") root.iface = parsed.meta.iface
        secured = parsed.meta.security !== "" && parsed.meta.security !== "nopass"
        if (qrSize > 0) error = ""
    }

    onOpenChanged: {
        if (open) {
            Qt.callLater(() => keyCatcher.forceActiveFocus())
        } else {
            expectedStop = true
            qrProc.running = false
            pwProc.running = false
            loading = false
            password = ""
            passwordVisible = false
        }
    }

    Process {
        id: qrProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: if (!root.expectedStop) root.updateQr(text)
        }
        stderr: StdioCollector {
            waitForEnd: true
            onStreamFinished: if (!root.expectedStop) root.error = String(text || "").trim()
        }
        onExited: function(exitCode) {
            root.loading = false
            if (root.expectedStop) return
            if (exitCode !== 0 || root.qrSize === 0) {
                root.qrSize = 0
                root.qrRows = []
                if (root.error === "") root.error = "Failed to generate QR code"
            }
        }
    }

    Process {
        id: pwProc
        stdout: StdioCollector {
            waitForEnd: true
            onStreamFinished: if (root.open && !root.expectedStop) root.password = String(text || "").trim()
        }
        onExited: function(exitCode) {
            if (root.expectedStop || !root.open) return
            if (exitCode === 0 && root.password !== "") root.passwordVisible = true
            else root.passwordError = "Could not read password"
        }
    }

    Rectangle {
        id: scrim
        anchors.fill: parent
        color: Qt.rgba(0, 0, 0, 0.78)

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }
    }

    Item {
        id: keyCatcher
        anchors.fill: parent
        focus: root.open

        Keys.onEscapePressed: root.close()

        Item {
            id: card
            anchors.centerIn: parent
            width: content.implicitWidth
            height: content.implicitHeight

            MouseArea {
                anchors.fill: parent
                onClicked: {}
            }

            ColumnLayout {
                id: content
                anchors.centerIn: parent
                spacing: 16

                Text {
                    text: (root.ssid || "Wi-Fi").toUpperCase()
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 11
                    font.bold: true
                    font.letterSpacing: 2
                    elide: Text.ElideRight
                    Layout.maximumWidth: 320
                    Layout.alignment: Qt.AlignHCenter
                    horizontalAlignment: Text.AlignHCenter
                }

                Rectangle {
                    id: qrCanvas
                    readonly property int moduleSize: root.qrSize > 0
                        ? Math.max(4, Math.floor(240 / root.qrSize))
                        : 0

                    visible: root.showingQr
                    width: root.qrSize * moduleSize
                    height: width
                    color: "white"
                    radius: Constants.radius
                    Layout.alignment: Qt.AlignHCenter

                    Grid {
                        anchors.fill: parent
                        columns: root.qrSize
                        LayoutMirroring.enabled: false

                        Repeater {
                            model: root.qrSize * root.qrSize

                            Rectangle {
                                required property int index
                                readonly property int matrixRow: Math.floor(index / root.qrSize)
                                readonly property int matrixColumn: index % root.qrSize

                                width: qrCanvas.moduleSize
                                height: qrCanvas.moduleSize
                                color: root.qrRows[matrixRow] && root.qrRows[matrixRow].charAt(matrixColumn) === "1" ? "#111111" : "transparent"
                            }
                        }
                    }
                }

                Text {
                    visible: root.loading
                    text: "Generating QR code…"
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    visible: root.error !== ""
                    text: root.error
                    color: "#f7768e"
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                    Layout.fillWidth: true
                    Layout.maximumWidth: 320
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    visible: root.showingQr
                    text: "Scan to join network"
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignHCenter
                }

                Text {
                    visible: root.showingQr && root.secured
                    text: root.passwordError !== "" ? root.passwordError
                        : root.passwordVisible ? root.password
                        : "Show password"
                    color: root.passwordError !== "" ? "#f7768e" : "white"
                    opacity: root.passwordVisible || root.passwordError !== "" ? 1 : 0.6
                    font.family: "JetBrainsMono Nerd Font"
                    font.pixelSize: 12
                    wrapMode: Text.WrapAnywhere
                    Layout.fillWidth: true
                    Layout.maximumWidth: 320
                    horizontalAlignment: Text.AlignHCenter

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.togglePassword()
                    }
                }
            }
        }
    }
}
