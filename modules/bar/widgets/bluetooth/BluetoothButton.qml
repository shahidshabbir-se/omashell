import QtQuick
import "../layout"

BarButton {
    readonly property var adapter: BluetoothRuntime.adapter

    visible: adapter !== null
    iconText: "󰂯"
    toggleOnRightClick: true
}
