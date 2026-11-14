import QtQuick
import "../../../../config"
import "../layout"

Item {
    id: root

    property bool active: false
    signal clicked

    readonly property bool available: MusicRuntime.hasCurrentPlayback

    visible: available
    implicitWidth: available ? Constants.barIconSlot : 0
    implicitHeight: available ? Constants.buttonSize : 0
    width: implicitWidth
    height: implicitHeight

    PopupAnchorSurface {
        anchors.fill: parent
        active: root.active

        Text {
            anchors.centerIn: parent
            text: "󰎈"
            color: Colors.foreground
            font.family: Constants.fontFamily
            font.pixelSize: Constants.iconSizeLg + 2
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (root.available)
                    root.clicked();
            }
        }
    }
}
