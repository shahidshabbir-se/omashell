import QtQuick
import qs.config

// Keyboard driver for a panel: one cursor that walks the navigable children of
// `container` with Up/Down (or Tab), activates with Return/Space, adjusts
// Left/Right on anything that exposes adjust(), and cancels with Escape.
//
// Our own version of "keyboard navigation": the panel owns the focus scope, each
// control draws its own cursor ring from `hasCursor`, and the controls know
// nothing about keys.
FocusScope {
  id: root

  property Item container: null
  property int index: 0

  readonly property var items: collect()
  readonly property Item current: (index >= 0 && index < items.length) ? items[index] : null

  signal canceled()

  focus: true

  // Walks the container in document order, descending through plain containers
  // (a toggle nested in a panel header, rows inside a group) and stopping at any
  // control that is itself navigable. Walk order therefore equals visual order
  // without the controls having to register anywhere.
  function collect() {
    var out = []
    function walk(item) {
      if (!item || item.children === undefined) return
      for (var i = 0; i < item.children.length; i++) {
        var child = item.children[i]
        if (!child || child.visible === false) continue
        if (child.navigable === true) {
          out.push(child)
          continue
        }
        walk(child)
      }
    }
    if (container) walk(container)
    return out
  }

  function sync() {
    var list = collect()
    if (list.length > 0 && root.index >= list.length) root.index = list.length - 1
    for (var i = 0; i < list.length; i++)
      list[i].hasCursor = (i === root.index)
  }

  function setIndex(next) {
    var list = collect()
    if (list.length === 0) return
    root.index = Math.max(0, Math.min(list.length - 1, next))
    sync()
  }

  function next() { setIndex(root.index + 1) }
  function previous() { setIndex(root.index - 1) }

  function activate() {
    if (root.current && typeof root.current.activate === "function") root.current.activate()
  }

  function adjust(delta) {
    if (root.current && typeof root.current.adjust === "function") root.current.adjust(delta)
  }

  // Called by the panel when it opens: take focus and put the cursor on the first
  // navigable control.
  function takeFocus() {
    root.forceActiveFocus()
    if (root.index === 0) sync()
    else setIndex(root.index)
  }

  onContainerChanged: { root.index = 0; sync() }
  Component.onCompleted: sync()

  Keys.onPressed: function(event) {
    var handled = true
    switch (event.key) {
    case Qt.Key_Down:
    case Qt.Key_Tab:
      next()
      break
    case Qt.Key_Up:
    case Qt.Key_Backtab:
      previous()
      break
    case Qt.Key_Return:
    case Qt.Key_Enter:
    case Qt.Key_Space:
      activate()
      break
    case Qt.Key_Left:
      // A text field needs the arrows for its caret; only adjust if the control
      // asked for it.
      if (root.current && typeof root.current.adjust === "function") adjust(-1)
      else handled = false
      break
    case Qt.Key_Right:
      if (root.current && typeof root.current.adjust === "function") adjust(1)
      else handled = false
      break
    case Qt.Key_Escape:
      root.canceled()
      break
    default:
      handled = false
    }
    if (handled) event.accepted = true
  }
}
