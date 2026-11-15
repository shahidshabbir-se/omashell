pragma Singleton

import QtQuick
import Quickshell.Io

                                                                                
                                                                                
QtObject {
  id: root

  readonly property var defaults: ({
    version: 1,
    bar: {
      left: ["logo", "workspaces"],
      center: ["clock", "worldclock", "weather"],
      right: ["notifications", "bluetooth", "network", "audio", "power"]
    }
  })

                                                                     
  property var raw: null

  readonly property int version: raw && raw.version !== undefined
    ? Number(raw.version)
    : defaults.version

  readonly property var bar: ({
    left: ids(source().left, defaults.bar.left),
    center: ids(source().center, defaults.bar.center),
    right: ids(source().right, defaults.bar.right)
  })

                                                                                
                                                                                 
                                                                     
  readonly property var widgetSettings: {
    var out = {}
    var src = source()
    var sections = [src.left, src.center, src.right]
    for (var s = 0; s < sections.length; s++) {
      var list = sections[s]
      if (typeof list !== "object" || list === null || typeof list.length !== "number")
        continue
      for (var i = 0; i < list.length; i++) {
        var entry = list[i]
        if (typeof entry !== "object" || entry === null || typeof entry.id !== "string" || entry.id === "")
          continue
        out[entry.id] = entry
      }
    }
    return out
  }

  function source() {
    return (raw && raw.bar) ? raw.bar : defaults.bar
  }

                                                                             
                                                                          
                                      
  function ids(list, fallback) {
                                                                                   
                                                                            
    if (typeof list !== "object" || list === null || typeof list.length !== "number")
      return fallback
    var out = []
    for (var i = 0; i < list.length; i++) {
      var raw = list[i]
                                                                         
      var id = (typeof raw === "object" && raw !== null) ? raw.id : raw
      if (typeof id !== "string" || id === "")
        continue
      if (out.indexOf(id) !== -1)
        continue
      out.push(id)
    }
    return out
  }

  function load(text) {
    try {
      var parsed = JSON.parse(text)
      root.raw = (parsed && typeof parsed === "object") ? parsed : null
    } catch (e) {
      console.warn("omashell: config/shell.json is not valid JSON, using defaults:", e.message)
      root.raw = null
    }
  }

                                                                            
                                                                            
  property FileView configFile: FileView {
    path: String(Qt.resolvedUrl("shell.json")).replace("file://", "")
    watchChanges: true
    printErrors: false

    onFileChanged: reload()
    onLoaded: root.load(text())
    onLoadFailed: root.raw = null
  }
}
