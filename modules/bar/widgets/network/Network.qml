import QtQuick
import Quickshell.Networking
import qs.common
import qs.config
import "Model.js" as Model






IconWidget {
  id: root

  readonly property var devices: Networking.devices ? Networking.devices.values : []
  readonly property var wiredDevice: findDevice(DeviceType.Wired)
  readonly property var wifiDevice: findDevice(DeviceType.Wifi)
  readonly property var wifiNetworks: root.wifiDevice && root.wifiDevice.networks
    ? root.wifiDevice.networks.values
    : []
  readonly property var connectedWifi: findConnectedWifi()
  readonly property bool networkManagerAvailable: Networking.backend === NetworkBackendType.NetworkManager

  readonly property string kind: {
    if (root.wiredDevice && root.wiredDevice.connected) return "ethernet"
    if (root.connectedWifi) return "wifi"
    if (root.wifiDevice && root.wifiDevice.connected) return "wifi"
    return "disconnected"
  }

  readonly property string connectivity: Model.connectivityState(root.kind, Networking.connectivity, {
    Portal: NetworkConnectivity.Portal,
    Limited: NetworkConnectivity.Limited,
    Full: NetworkConnectivity.Full,
    None: NetworkConnectivity.None
  }, root.networkManagerAvailable && Networking.canCheckConnectivity && Networking.connectivityCheckEnabled)

  readonly property int signalStrength: root.kind === "wifi"
    ? Model.connectedSignalStrength(root.connectedWifi ? root.connectedWifi.signalStrength : 0, -1)
    : -1

  readonly property bool restricted: root.connectivity === "portal" || root.connectivity === "limited"

  glyph: Model.connectionIcon(root.kind, root.signalStrength, root.connectivity)
  color: root.restricted ? Colors.red : Colors.foreground

  tooltip: {
    if (!root.setting("showTooltip", false)) return ""
    if (root.kind === "ethernet") return root.restricted ? "Ethernet · limited access" : "Ethernet"
    if (root.kind === "wifi") {
      var name = root.connectedWifi && root.connectedWifi.name
        ? root.connectedWifi.name
        : (root.wifiDevice ? root.wifiDevice.name : "Wi-Fi")
      if (root.connectivity === "portal") return name + " · sign-in required"
      if (root.connectivity === "limited") return name + " · limited access"
      return name + " · " + root.signalStrength + "%"
    }
    return "Offline"
  }

                                                                           
                                           
  function findDevice(type) {
    var list = root.devices
    var fallback = null
    for (var i = 0; i < list.length; i++) {
      var device = list[i]
      if (!device || device.type !== type) continue
      if (device.connected) return device
      if (!fallback) fallback = device
    }
    return fallback
  }

  function findConnectedWifi() {
    for (var i = 0; i < root.wifiNetworks.length; i++) {
      if (root.wifiNetworks[i] && root.wifiNetworks[i].connected) return root.wifiNetworks[i]
    }
    return null
  }
}
