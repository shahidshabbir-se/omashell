import QtQuick

                                                                                    
                                                                                
                                                                            
QtObject {
  id: root

  property var adapter: null
                                                   
  property bool active: false

  property var owns: null
  property int attempts: 0

  function start() {
    if (!root.adapter || !root.adapter.enabled) return
                                                                               
                                                                  
    root.owns = root.adapter
    if (!root.adapter.discovering) root.adapter.discovering = true
  }

  function stop() {
    if (!root.owns) return
    root.attempts = 0
    root.attemptStop()
  }

  function attemptStop() {
    var adapter = root.owns
    if (!adapter || !adapter.discovering) {
      root.owns = null
      return
    }
    if (root.attempts >= 3) {
      root.owns = null
      return
    }
    root.attempts++
    adapter.discovering = false
    retry.restart()
  }

  onActiveChanged: root.active ? root.start() : root.stop()

  property Timer startRetry: Timer {
    interval: 1000
    repeat: true
    triggeredOnStart: true
    running: root.active && root.adapter !== null && root.adapter.enabled && !root.adapter.discovering
    onTriggered: root.start()
  }

                                                                                    
  property Connections adapterWatch: Connections {
    id: adapterWatch
    target: root.adapter

    function onEnabledChanged() {
      if (root.active) root.start()
      else root.stop()
    }

    function onDiscoveringChanged() {
                                                            
      if (root.owns && !root.owns.discovering) root.owns = null
    }
  }

  property Timer retryTimer: Timer {
    id: retry
    interval: 400
    onTriggered: root.attemptStop()
  }
}
