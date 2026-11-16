import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Isolated persistence harness. It is launched by run-config-persistence-tests.sh
// with a disposable HOME/XDG_CONFIG_HOME and a temp QML root containing
// symlinks to this checkout's config/ and modules/ directories.
ShellRoot {
  id: harness

  readonly property string phase: String(Quickshell.env("OMASHELL_CONFIG_TEST_PHASE") || "")
  readonly property string expectedPosition: String(Quickshell.env("OMASHELL_CONFIG_TEST_EXPECT_POSITION") || "")
  readonly property int expectedFormat: Number(Quickshell.env("OMASHELL_CONFIG_TEST_EXPECT_FORMAT") || 0)

  property bool finished: false
  property int savedCount: 0

  signal savedByConfig()

  Connections {
    target: Config.configFile
    function onSaved() {
      harness.savedCount++
      harness.savedByConfig()
    }
  }

  FileView {
    id: diskFile
    path: Config.userConfigPath
    blockAllReads: true
    printErrors: false
  }

  FileView {
    id: externalFile
    path: Config.userConfigPath
    atomicWrites: true
    printErrors: false
  }

  Process {
    id: unlinkProcess
    command: ["unlink", Config.userConfigPath]
  }

  Timer {
    id: globalTimeout
    interval: 10000
    running: true
    onTriggered: harness.fail("global timeout in phase " + harness.phase)
  }

  Timer {
    id: pollTimer
    interval: 10
    repeat: false
    property var callback: null
    onTriggered: if (callback) callback()
  }

  Timer {
    id: delayTimer
    repeat: false
    property var callback: null
    onTriggered: if (callback) callback()
  }

  Item {
    Component.onCompleted: harness.start()
  }

  function finish(code) {
    if (harness.finished) return
    harness.finished = true
    globalTimeout.stop()
    Qt.exit(code)
  }

  function fail(message) {
    console.log("TEST FAIL: " + message)
    finish(1)
  }

  function pass(message) {
    console.log("TEST PASS: " + message)
    finish(0)
  }

  function check(condition, message) {
    if (condition) {
      console.log("CHECK OK: " + message)
      return true
    }
    fail("failed check: " + message)
    return false
  }

  function waitUntil(description, predicate, callback, timeout) {
    var deadline = Date.now() + (timeout || 4000)
    function poll() {
      if (harness.finished) return
      var matched = false
      try {
        matched = !!predicate()
      } catch (e) {
        harness.fail("exception waiting for " + description + ": " + e)
        return
      }
      if (matched) {
        callback()
        return
      }
      if (Date.now() >= deadline) {
        harness.fail("timeout waiting for " + description)
        return
      }
      pollTimer.callback = poll
      pollTimer.restart()
    }
    poll()
  }

  function delay(milliseconds, callback) {
    delayTimer.interval = milliseconds
    delayTimer.callback = callback
    delayTimer.restart()
  }

  function waitForSave(baseline, description, callback) {
    waitUntil(description, function() {
      return harness.savedCount > baseline
        && Config.pendingWrite === ""
        && !Config.configReloadPending
        && Config.configReady
    }, callback)
  }

  function readDisk() {
    diskFile.reload()
    return diskFile.text()
  }

  function diskConfig() {
    var text = readDisk()
    try {
      return { text: text, config: JSON.parse(text) }
    } catch (e) {
      return { text: text, error: String(e) }
    }
  }

  function clockFormat(config) {
    var entry = entryFor(config, "clock")
    return entry && typeof entry === "object" && entry.format !== undefined ? Number(entry.format) : 0
  }

  function currentClockFormat() {
    var entry = Config.widgetSettings ? Config.widgetSettings.clock : null
    return entry && entry.format !== undefined ? Number(entry.format) : 0
  }

  function entryFor(config, id) {
    var names = ["left", "centerBegin", "center", "centerEnd", "right"]
    var bar = config && config.bar ? config.bar : ({})
    for (var s = 0; s < names.length; s++) {
      var list = bar[names[s]]
      if (!Array.isArray(list)) continue
      for (var i = 0; i < list.length; i++) {
        var entry = list[i]
        var entryId = typeof entry === "string" ? entry : (entry && entry.id)
        if (entryId === id) return entry
      }
    }
    return null
  }

  function hasEntry(config, id) {
    return entryFor(config, id) !== null
  }

  function checkNewline(text, label) {
    check(text.length > 0 && text.charAt(text.length - 1) === "\n", label + " ends with a newline")
    check(text.indexOf("\\n") === -1, label + " has no literal backslash-n")
    check(text.length < 2 || text.charAt(text.length - 2) !== "\n", label + " has exactly one trailing newline")
  }

  function checkDisk(label, position, format, extraId) {
    var read = diskConfig()
    if (read.error) {
      fail(label + " is not valid JSON: " + read.error)
      return false
    }
    checkNewline(read.text, label)
    check(read.config.bar && read.config.bar.position === position,
      label + " persists bar position " + position)
    check(clockFormat(read.config) === format, label + " persists clock format " + format)
    if (extraId) check(hasEntry(read.config, extraId), label + " keeps widget " + extraId)
    return true
  }

  function start() {
    if (phase === "bundled-defaults") startBundledDefaults()
    else if (phase === "startup-race") startStartupRace()
    else if (phase === "startup-no-user") startStartupNoUser()
    else if (phase === "restart-verify") startRestartVerify()
    else if (phase === "external-edit") startExternalEdit()
    else if (phase === "invalid-external") startInvalidExternal()
    else if (phase === "external-delete") startExternalDelete()
    else fail("unknown phase: " + phase)
  }

  function indicatorItems(config) {
    var entry = entryFor(config, "indicators")
    return entry && typeof entry === "object" && Array.isArray(entry.items) ? entry.items : []
  }

  // The bundled file must match the Omarchy reference default bar: the
  // notification service has no bar widget there. The DND indicator stays.
  function startBundledDefaults() {
    waitUntil("bundled default configuration to load", function() {
      return Config.configReady && Config.raw && Config.raw.bar
    }, function() {
      check(Config.raw.bar.right.indexOf("notifications") === -1,
        "bundled right section excludes the notification menu widget")
      check(Config.raw.bar.right.indexOf("bluetooth") !== -1
        && Config.raw.bar.right.indexOf("power") !== -1,
        "bundled right section keeps the regular widgets")
      check(Config.bar.centerBegin.indexOf("indicators") !== -1,
        "bundled centerBegin keeps indicators")
      check(indicatorItems(Config.raw).indexOf("Dnd") !== -1,
        "bundled indicators keep the DND indicator")
      check(indicatorItems(Config.raw).indexOf("StayAwake") !== -1,
        "bundled indicators keep stay-awake")
      check(Config.defaults.bar.right.indexOf("notifications") === -1,
        "built-in fallback defaults exclude the notification menu widget")
      check(Config.bar.right.indexOf("notifications") === -1,
        "effective default right section excludes the notification menu widget")
      pass("bundled defaults match the reference bar layout")
    })
  }

  // A setting changed during component creation, before the asynchronous
  // user-file read has completed, must be replayed on top of that file rather
  // than becoming a write of the built-in defaults.
  function startStartupRace() {
    var baseline = savedCount
    Config.setWidgetSetting("clock", "format", 5)
    waitUntil("user configuration to load", function() {
      return Config.configReady && Config.userConfigAvailable
    }, function() {
      check(Config.bar.position === "bottom", "startup mutation keeps the user's bar position")
      check(currentClockFormat() === 5, "startup mutation applies the clock setting")
      waitForSave(baseline, "startup mutation to save", function() {
        var read = diskConfig()
        if (read.error) {
          fail("startup write is not valid JSON: " + read.error)
          return
        }
        if (!checkDisk("startup write", "bottom", 5, "workspaces")) return
        check(hasEntry(read.config, "indicators"), "startup write fills missing default indicators")
        check(hasEntry(read.config, "weather"), "startup write fills missing default centerEnd widgets")
        pass("startup race preserves the existing user configuration")
      })
    })
  }

  // With no user file the bundled defaults are the fallback source. An early
  // mutation must survive the fallback load and become the first user file.
  function startStartupNoUser() {
    var baseline = savedCount
    Config.mutateBar(function(bar) { bar.position = "bottom" })
    Config.setWidgetSetting("clock", "format", 6)
    waitUntil("bundled fallback to load", function() {
      return Config.configReady
    }, function() {
      check(Config.bar.position === "bottom", "early mutation applies after fallback")
      check(currentClockFormat() === 6, "early clock setting applies after fallback")
      waitForSave(baseline, "first user file to save", function() {
        var read = diskConfig()
        if (read.error) {
          fail("fallback write is not valid JSON: " + read.error)
          return
        }
        if (!checkDisk("first write", "bottom", 6, "workspaces")) return
        check(hasEntry(read.config, "indicators"), "first write keeps default indicators")
        check(hasEntry(read.config, "weather"), "first write keeps default centerEnd widgets")
        pass("fallback configuration survives an early mutation")
      })
    })
  }

  function startRestartVerify() {
    waitUntil("persisted user configuration to load", function() {
      return Config.configReady && Config.userConfigAvailable
    }, function() {
      check(Config.bar.position === expectedPosition,
        "restart loads bar position " + expectedPosition)
      check(currentClockFormat() === expectedFormat,
        "restart loads clock format " + expectedFormat)
      var read = diskConfig()
      if (read.error) {
        fail("restart file is not valid JSON: " + read.error)
        return
      }
      checkNewline(read.text, "restart file")
      pass("restart loads persisted position and clock settings")
    })
  }

  function startExternalEdit() {
    waitUntil("initial user configuration to load", function() {
      return Config.configReady && Config.userConfigAvailable
    }, function() {
      externalFile.setText(JSON.stringify({
        version: 1,
        bar: {
          position: "left",
          left: ["logo", "customExtern"],
          centerBegin: [],
          center: [{ id: "clock", format: 7 }],
          centerEnd: [],
          right: ["audio"]
        }
      }, null, 2) + "\n")
      waitUntil("external edit to reload", function() {
        return !Config.configReloadPending
          && Config.bar.position === "left"
          && currentClockFormat() === 7
      }, function() {
        var baseline = savedCount
        Config.setWidgetSetting("clock", "format", 8)
        Config.mutateBar(function(bar) { bar.position = "right" })
        waitForSave(baseline, "merged external edit to save", function() {
          if (!checkDisk("external merge", "right", 8, "customExtern")) return
          pass("external edit reloads and merges with a local mutation")
        })
      })
    })
  }

  function startInvalidExternal() {
    waitUntil("initial user configuration to load", function() {
      return Config.configReady && Config.userConfigAvailable
    }, function() {
      var invalid = "{ this is not json\n"
      externalFile.setText(invalid)
      waitUntil("invalid external edit to reload", function() {
        return Config.userConfigUnreadable && !Config.configReloadPending
      }, function() {
        var baseline = savedCount
        Config.setWidgetSetting("clock", "format", 9)
        delay(300, function() {
          check(savedCount === baseline, "unreadable user file is not overwritten")
          check(readDisk() === invalid, "unreadable user file is preserved byte for byte")
          var valid = JSON.stringify({
            version: 1,
            bar: {
              position: "left",
              left: ["logo", "customValid"],
              centerBegin: [],
              center: [{ id: "clock", format: 10 }],
              centerEnd: [],
              right: []
            }
          }, null, 2) + "\n"
          externalFile.setText(valid)
          waitUntil("fixed external edit to reload", function() {
            return Config.configReady
              && !Config.userConfigUnreadable
              && !Config.configReloadPending
              && Config.bar.position === "left"
              && currentClockFormat() === 10
          }, function() {
            var secondBaseline = savedCount
            Config.setWidgetSetting("clock", "format", 11)
            waitForSave(secondBaseline, "write after recovery to save", function() {
              if (!checkDisk("recovered write", "left", 11, "customValid")) return
              pass("invalid external edit is preserved until fixed, then writes resume")
            })
          })
        })
      })
    })
  }

  function startExternalDelete() {
    waitUntil("initial user configuration to load", function() {
      return Config.configReady && Config.userConfigAvailable
    }, function() {
      unlinkProcess.running = true
      waitUntil("fallback after external deletion", function() {
        return Config.configReady
          && !Config.userConfigAvailable
          && Config.bar.position === "top"
      }, function() {
        var baseline = savedCount
        Config.setWidgetSetting("clock", "format", 12)
        waitForSave(baseline, "recreated user file to save", function() {
          var read = diskConfig()
          if (read.error) {
            fail("recreated file is not valid JSON: " + read.error)
            return
          }
          if (!checkDisk("recreated write", "top", 12, "workspaces")) return
          check(hasEntry(read.config, "indicators"), "recreated file keeps default indicators")
          check(hasEntry(read.config, "weather"), "recreated file keeps default centerEnd widgets")
          pass("external deletion falls back, then recreates a user file")
        })
      })
    })
  }
}
