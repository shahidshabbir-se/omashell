import QtQuick
import "../../../../config"

Item {
    id: root
    property var runtime
    property bool active: false
    signal clicked()

    implicitWidth: Constants.buttonSize
    implicitHeight: Constants.buttonSize

    Rectangle {
        anchors.fill: parent
        color: root.active || pointer.containsMouse ? Colors.backgroundRaised : "transparent"
    }
    Text {
        anchors.centerIn: parent
        text: root.runtime ? root.runtime.icon : ""
        color: root.runtime && root.runtime.muted ? Colors.statusDanger : Colors.foreground
        font.family: Constants.fontFamily
        font.pixelSize: Constants.iconSizeLg
    }
    MouseArea {
        id: pointer
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (root.runtime) root.runtime.toggleMute()
            } else root.clicked()
        }
    }
}
