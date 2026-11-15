import QtQuick
import Quickshell.Bluetooth
import qs.common
import qs.config

                                                                                
                                                                                
                                                                                 
IconWidget {
  id: root

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property var devices: Bluetooth.devices ? Bluetooth.devices.values : []

  readonly property int connectedCount: {
    var count = 0
    for (var i = 0; i < root.devices.length; i++) {
      if (root.devices[i] && root.devices[i].connected) count++
    }
    return count
  }

                                                             
  visible: root.adapter !== null
  glyph: root.adapter === null ? ""
    : (!root.adapter.enabled ? "\uDB80\uDCB2"
      : (root.connectedCount > 0 ? "\uDB80\uDCB1" : "\uDB80\uDCAF"))

  tooltip: root.adapter === null ? ""
    : (!root.adapter.enabled ? "Bluetooth off"
      : (root.connectedCount > 0
        ? root.connectedCount + (root.connectedCount === 1 ? " device connected" : " devices connected")
        : "Bluetooth on"))

                                                                                  
                          
}
