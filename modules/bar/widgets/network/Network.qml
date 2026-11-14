import QtQuick
import "../../../../config"
import "../layout"
import "Model.js" as Model

BarButton {
    id: root

    iconText: root.icon
    iconColor: restricted ? Colors.statusDanger : Colors.foreground

    readonly property bool networkManagerAvailable: NetworkRuntime.networkManagerAvailable
    readonly property var wiredDevice: NetworkRuntime.wiredDevice
    readonly property var wifiDevice: NetworkRuntime.wifiDevice
    readonly property var connectedWifiNetwork: NetworkRuntime.connectedWifiNetwork
    readonly property string kind: NetworkRuntime.kind
    readonly property int signalStrength: NetworkRuntime.signalStrength
    readonly property string connectivity: NetworkRuntime.connectivity

    readonly property bool restricted: connectivity === "portal" || connectivity === "limited"
    readonly property string icon: Model.connectionIcon(kind, signalStrength, connectivity)

    component Popup: NetworkPopup {}
}
