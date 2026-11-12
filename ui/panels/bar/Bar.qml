import QtQuick
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: root

    anchors {
        top: true
        left: true
        right: true
    }

    implicitHeight: 32
    color: "#1e1e2e"

    Text {
        anchors {
            left: parent.left
            verticalCenter: parent.verticalCenter
            leftMargin: 12
        }

        text: "Quickshell"
        color: "#cdd6f4"
        font.pixelSize: 13
    }

    Text {
        anchors.centerIn: parent

        text: Qt.formatDateTime(new Date(), "hh:mm AP")
        color: "#cdd6f4"
        font.pixelSize: 13
    }

    Text {
        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
            rightMargin: 12
        }

        text: "󰤨"
        color: "#cdd6f4"
        font.pixelSize: 16
    }
}
