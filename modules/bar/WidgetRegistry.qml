pragma Singleton

import QtQuick

                                                                                
                                                                               
                                                                                 
  
                                                                               
                                                       
QtObject {
  id: root

  readonly property var widgets: ({
    logo: Qt.resolvedUrl("widgets/logo/Logo.qml"),
    indicators: Qt.resolvedUrl("widgets/indicators/Indicators.qml"),
    notifications: Qt.resolvedUrl("../notifications/Notifications.qml"),
    workspaces: Qt.resolvedUrl("widgets/workspaces/Workspaces.qml"),
    clock: Qt.resolvedUrl("widgets/clock/Clock.qml"),
    weather: Qt.resolvedUrl("widgets/weather/Weather.qml"),
    worldclock: Qt.resolvedUrl("widgets/worldclock/WorldClock.qml"),
    bluetooth: Qt.resolvedUrl("widgets/bluetooth/Bluetooth.qml"),
    network: Qt.resolvedUrl("widgets/network/Network.qml"),
    audio: Qt.resolvedUrl("widgets/audio/Audio.qml"),
    power: Qt.resolvedUrl("widgets/power/Power.qml")
  })

                                                                            
                                                           
  function urlFor(id) {
    var url = root.widgets[id]
    return url !== undefined ? url : ""
  }

  function known(id) {
    return root.widgets[id] !== undefined
  }
}
