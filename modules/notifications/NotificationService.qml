pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import 'Model.js' as Model

QtObject {
  id: root

  property var server: NotificationServer {
    keepOnReload: true
    bodySupported: true
    bodyMarkupSupported: true
    bodyHyperlinksSupported: true
    actionsSupported: true
    imageSupported: true
    onNotification: function(notification) { root.accept(notification) }
  }

  property var live: []
  property var history: []
  property bool dnd: false
  property double nowTick: Date.now()
  property int keySeed: 0
  property int revision: 0
  property bool stateReady: false
  property bool savePending: false
  property string deckScreen: ''
  readonly property int maxLive: 4
  readonly property int unread: live.length
  readonly property string stateDir: (Quickshell.env('XDG_STATE_HOME') || (Quickshell.env('HOME') + '/.local/state')) + '/omashell'
  readonly property string statePath: root.stateDir + '/notifications.json'
  property var refs: ({})
  property var watched: ({})

  function findKey(id) {
    if (!id) return ''
    for (var key in refs) {
      var note = refs[key]
      if (note && Number(note.id) === Number(id)) return key
    }
    return ''
  }

  function accept(notification) {
    if (!notification) return
    var key = root.findKey(notification.id)
    if (key === '') {
      root.keySeed += 1
      key = 'n' + root.keySeed
    }
    var previous = root.refs[key]
    if (previous && previous !== notification) {
      try { previous.tracked = false } catch (e) {}
    }
    notification.tracked = true
    var refs = Object.assign({}, root.refs)
    refs[key] = notification
    root.refs = refs
    root.watch(notification, key)
    var row = Model.snapshot({
      id: notification.id,
      app: notification.appName,
      appIcon: notification.appIcon,
      summary: notification.summary,
      body: notification.body,
      urgency: notification.urgency,
      actions: notification.actions,
      resident: notification.resident,
      transient: notification.transient,
      timeout: notification.expireTimeout
    }, key, root.nowTick)
    row.duration = Model.durationFor(row.urgency, row.timeout)
    root.revision += 1
    if (Model.quietReason(row, root.dnd) !== '') {
      if (!Model.isEphemeral(row)) root.record(row, 'silenced')
      root.forget(key)
      return
    }
    root.put(row)
  }

  function watch(notification, key) {
    if (root.watched[key] === notification) return
    var watched = Object.assign({}, root.watched)
    watched[key] = notification
    root.watched = watched
    var refresh = function() {
      if (root.refs[key] !== notification) return
      root.accept(notification)
    }
    var close = function(reason) { root.closed(key, notification, reason) }
    notification.closed.connect(close)
    notification.summaryChanged.connect(refresh)
    notification.bodyChanged.connect(refresh)
    notification.urgencyChanged.connect(refresh)
    notification.actionsChanged.connect(refresh)
  }

  function closed(key, notification, reason) {
    if (root.refs[key] !== notification) return
    var row = root.rowFor(key)
    root.forget(key)
    if (!row) return
    root.remove(key)
    var reasonName = Number(reason) === NotificationCloseReason.Dismissed ? 'dismissed'
      : Number(reason) === NotificationCloseReason.CloseRequested ? 'closed' : 'expired'
    root.record(row, reasonName)
  }

  function forget(key) {
    var refs = Object.assign({}, root.refs)
    delete refs[key]
    root.refs = refs
    var watched = Object.assign({}, root.watched)
    delete watched[key]
    root.watched = watched
  }

  function rowFor(key) {
    for (var i = 0; i < root.live.length; i++)
      if (root.live[i].key === key) return root.live[i]
    return null
  }

  function put(row) {
    var next = []
    var replaced = false
    for (var i = 0; i < root.live.length; i++) {
      if (root.live[i].key === row.key) { next.push(row); replaced = true }
      else next.push(root.live[i])
    }
    if (!replaced) next.unshift(row)
    root.live = next.slice(0, root.maxLive)
    root.revision += 1
  }

  function remove(key) {
    var next = []
    for (var i = 0; i < root.live.length; i++)
      if (root.live[i].key !== key) next.push(root.live[i])
    root.live = next
    root.revision += 1
  }

  function record(row, reason) {
    if (!row || Model.isEphemeral(row)) return
    root.history = Model.cap([Model.entry(row, reason, root.nowTick)].concat(root.history), Model.MAX_HISTORY)
    root.saveSoon()
  }

  function dismiss(row) {
    if (!row) return
    var note = root.refs[row.key]
    if (note) {
      try { note.dismiss(); return } catch (e) {}
    }
    root.remove(row.key)
    root.record(row, 'dismissed')
    root.forget(row.key)
  }

  function expire(row) {
    if (!row) return
    var note = root.refs[row.key]
    if (note) {
      try { note.expire(); return } catch (e) {}
    }
    root.remove(row.key)
    root.record(row, 'expired')
    root.forget(row.key)
  }

  function invoke(row, actionId) {
    if (!row) return
    var note = root.refs[row.key]
    if (!note) return
    var list = note.actions || []
    for (var i = 0; i < list.length; i++) {
      var action = list[i]
      var id = String(action && (action.identifier !== undefined ? action.identifier : action.id) || '')
      var text = String(action && action.text || '')
      if (String(actionId || '') === '' || id === String(actionId) || text === String(actionId)) {
        action.invoke()
        return
      }
    }
  }

  function activate(row) {
    root.invoke(row, '')
    root.expire(row)
  }

  function dismissAll() {
    var rows = root.live.slice()
    for (var i = rows.length - 1; i >= 0; i--) root.dismiss(rows[i])
  }

  function clear() {
    root.history = []
    root.saveSoon()
  }

  function removeHistory(index) {
    if (index < 0 || index >= root.history.length) return
    var next = root.history.slice()
    next.splice(index, 1)
    root.history = next
    root.saveSoon()
  }

  function setDnd(value) {
    var on = !!value
    if (on === root.dnd) return
    root.dnd = on
    root.saveSoon()
  }

  function toggleDnd() { root.setDnd(!root.dnd) }

  property Timer ticker: Timer {
    interval: 20000
    repeat: true
    running: root.live.length > 0 || root.history.length > 0
    onTriggered: root.nowTick = Date.now()
  }

  property Timer saveTimer: Timer {
    interval: 300
    onTriggered: root.save()
  }

  function saveSoon() {
    root.savePending = true
    root.saveTimer.restart()
  }

  function save() {
    if (!root.stateReady || !root.stateFile) return
    root.savePending = false
    root.stateFile.setText(Model.serialise({ dnd: root.dnd, history: root.history }))
  }

  function loadState(text) {
    var state = Model.parseState(text)
    root.dnd = state.dnd
    root.history = state.history
  }

  property var stateFile: null

  property Component stateComponent: Component {
    FileView {
      watchChanges: false
      printErrors: false
      onLoaded: root.loadState(text())
      onLoadFailed: root.save()
    }
  }

  property Process dirProc: Process {
    command: ['mkdir', '-p', root.stateDir]
    onExited: {
      root.stateReady = true
      root.stateFile = root.stateComponent.createObject(root, { path: root.statePath })
    }
  }

  Component.onCompleted: root.dirProc.running = true
}
