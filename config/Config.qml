pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../modules/bar/BarModel.js" as BarModel

                                                                                
                                                                                
QtObject {
  id: root

  readonly property string userConfigPath: {
    var base = Quickshell.env('XDG_CONFIG_HOME')
    if (!base && Quickshell.env('HOME')) base = Quickshell.env('HOME') + '/.config'
    return base ? base + '/omashell/shell.json' : ''
  }
  readonly property string bundledConfigPath: {
    var path = String(Qt.resolvedUrl('shell.json'))
    if (path.indexOf('file://') === 0) path = path.substring(7)
    try { path = decodeURIComponent(path) } catch (e) {}
    return path
  }

  readonly property var defaults: ({
    version: 1,
    bar: {
      position: "top",
      left: ["logo", "workspaces"],
      centerBegin: ["indicators"],
      center: ["clock"],
      centerEnd: ["worldclock", "weather"],
      right: ["bluetooth", "network", "audio", "power"]
    }
  })

                                                                     
  property var raw: null
  property bool userConfigAvailable: false
  property bool userConfigResolved: false
  property bool userConfigUnreadable: false
  property bool configReady: false
  property bool configReloadPending: true
  property var queuedMutations: []

  readonly property int version: raw && raw.version !== undefined
    ? Number(raw.version)
    : defaults.version

  readonly property var bar: {
    var sourceConfig = root.raw || root.defaults
    var sections = BarModel.configSections(sourceConfig, root.defaults.bar)
    return {
      position: BarModel.normalizePosition(sourceConfig && sourceConfig.bar ? sourceConfig.bar.position : root.defaults.bar.position),
      left: ids(sections.left, defaults.bar.left),
      centerBegin: ids(sections.centerBegin, defaults.bar.centerBegin),
      center: ids(sections.center, defaults.bar.center),
      centerEnd: ids(sections.centerEnd, defaults.bar.centerEnd),
      right: ids(sections.right, defaults.bar.right)
    }
  }

                                                                                
                                                                                 
                                                                     
  readonly property var widgetSettings: {
    var out = {}
    var sourceConfig = root.raw || root.defaults
    var sections = BarModel.configSections(sourceConfig, root.defaults.bar)
    for (var s = 0; s < BarModel.sectionNames.length; s++) {
      var list = sections[BarModel.sectionNames[s]]
      for (var i = 0; i < list.length; i++) {
        var entry = list[i]
        if (typeof entry === "object" && entry !== null && typeof entry.id === "string")
          out[entry.id] = entry
      }
    }
    return out
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
      if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) {
        console.warn("omashell: config/shell.json must contain a JSON object, using defaults")
        root.raw = null
        return false
      }
      root.raw = parsed
      return true
    } catch (e) {
      console.warn("omashell: config/shell.json is not valid JSON, using defaults:", e.message)
      root.raw = null
      return false
    }
  }

  function applyBarMutation(mutator) {
    if (typeof mutator !== "function") return false
    var next = BarModel.normalizeConfig(root.raw || root.defaults, root.defaults.bar)
    var before = JSON.stringify(next)
    mutator(next.bar)
    var changed = JSON.stringify(next) !== before
    root.raw = next
    if (!changed) return false
    if (root.userConfigUnreadable) {
      console.warn("omashell: not writing config/shell.json because the existing file could not be read; fix it to save changes")
      return true
    }
    if (root.userConfigPath === "") {
      console.warn("omashell: no user config path is available; changes will not persist")
      return true
    }
    pendingWrite = JSON.stringify(next, null, 2) + "\n"
    directoryProc.running = true
    return true
  }

  function mutateBar(mutator) {
    if (typeof mutator !== "function") return false
    // Never build a write from the built-in defaults while the user file is
    // still loading or being reloaded. Mutating now would overwrite whatever
    // is already on disk, so defer until the canonical source is settled.
    if (!root.configReady || root.configReloadPending) {
      root.queuedMutations.push(mutator)
      return true
    }
    return root.applyBarMutation(mutator)
  }

  function flushQueuedMutations() {
    if (!root.configReady || root.configReloadPending) return
    var queued = root.queuedMutations
    root.queuedMutations = []
    for (var i = 0; i < queued.length; i++) root.applyBarMutation(queued[i])
  }

  function markConfigReady() {
    root.configReloadPending = false
    root.configReady = true
    root.flushQueuedMutations()
  }

  function setWidgetSetting(id, name, value) {
    var changed = false
    var queued = !root.configReady || root.configReloadPending
    mutateBar(function(bar) {
      changed = BarModel.setWidgetSetting(bar, String(id), String(name), value)
    })
    return queued || changed
  }

  property string pendingWrite: ""

  property Process directoryProc: Process {
    command: ["mkdir", "-p", root.userConfigDirectory]
    onExited: function(exitCode) {
      if (exitCode !== 0) {
        if (root.pendingWrite !== "")
          console.warn("omashell: could not create config directory", root.userConfigDirectory)
        return
      }
      if (root.pendingWrite === "" || root.userConfigUnreadable) return
      var text = root.pendingWrite
      root.pendingWrite = ""
      root.configFile.setText(text)
    }
  }

  readonly property string userConfigDirectory: userConfigPath === "" ? "" : userConfigPath.substring(0, userConfigPath.lastIndexOf("/"))

                                                                            
                                                                            
  property FileView configFile: FileView {
    path: root.userConfigPath
    watchChanges: true
    atomicWrites: true
    printErrors: false

    onFileChanged: {
      root.configReloadPending = true
      reload()
    }
    onLoaded: {
      root.userConfigAvailable = true
      root.userConfigResolved = true
      root.userConfigUnreadable = !root.load(text())
      root.markConfigReady()
    }
    onLoadFailed: {
      root.userConfigAvailable = false
      root.userConfigResolved = true
      root.userConfigUnreadable = false
      root.configReady = false
      root.configReloadPending = true
      fallbackFile.reload()
    }
    onSaved: {
      // A watched write reports fileChanged before saved. Its reload is
      // ignored while the write is in flight, so settle here instead of
      // leaving queued edits waiting for a load that will never arrive.
      if (root.configReloadPending) {
        root.configReloadPending = false
        root.flushQueuedMutations()
      }
    }
    onSaveFailed: function(error) {
      console.warn("omashell: could not write config/shell.json:", error)
      if (root.configReloadPending) {
        root.configReloadPending = false
        root.flushQueuedMutations()
      }
    }
  }

  property FileView fallbackFile: FileView {
    path: root.bundledConfigPath
    watchChanges: true
    printErrors: false

    onLoaded: {
      if (!root.userConfigAvailable) root.load(text())
      if (root.userConfigResolved && !root.userConfigAvailable) root.markConfigReady()
    }
    onLoadFailed: {
      if (!root.userConfigAvailable) root.raw = null
      if (root.userConfigResolved && !root.userConfigAvailable) root.markConfigReady()
    }
  }
}
