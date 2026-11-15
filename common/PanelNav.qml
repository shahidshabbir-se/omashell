import QtQuick
import qs.config

                                                                           
                                                                                
                                                
FocusScope {
  id: root

  property Item container: null
  property int index: 0
  property bool cursorActive: false
                                                                        
  property bool customNavigation: false
  property var items: []

  readonly property Item current: index >= 0 && index < items.length ? items[index] : null

  signal canceled()
  signal tabRequested(int direction)
  signal deleteRequested()
  signal textRequested(string text)
  signal horizontalRequested(int direction)
  signal moveRequested(int dx, int dy)

  focus: true
  Keys.priority: Keys.BeforeItem

  function collect() {
    var out = []
    var visited = []
    function walk(item) {
      if (!item || visited.indexOf(item) >= 0) return
      visited.push(item)
      if (item.visible === false) return
      if (item.navigable === true) {
        out.push(item)
        return
      }

                                                                                 
                                                                              
      if (typeof item.itemAt === "function" && Number(item.count) > 0) {
        for (var n = 0; n < item.count; n++) walk(item.itemAt(n))
      }
      if (item.contentItem) walk(item.contentItem)
      if (item.children !== undefined) {
        var children = item.children
        for (var i = 0; i < children.length; i++) walk(children[i])
      }
    }
    walk(container)
    return out
  }

  function sync() {
    var list = root.items
    if (list.length > 0 && root.index >= list.length) root.index = list.length - 1
    if (list.length === 0) root.index = 0
    for (var i = 0; i < list.length; i++)
      list[i].hasCursor = root.cursorActive && i === root.index
  }

                                                                                 
                                                                                   
  function refresh() {
    var oldKey = root.current && root.current.navigationKey ? root.current.navigationKey : ""
    var next = collect()
    root.items = next
    if (oldKey !== "") {
      for (var i = 0; i < next.length; i++) {
        if (next[i].navigationKey === oldKey) {
          root.index = i
          sync()
          return
        }
      }
    }
    sync()
  }

  function clearCurrentAction(nextIndex) {
    if (nextIndex !== root.index && root.current && typeof root.current.clearAction === "function")
      root.current.clearAction()
  }

  function setIndex(next) {
    if (root.items.length === 0) return
    var target = Math.max(0, Math.min(root.items.length - 1, next))
    clearCurrentAction(target)
    root.index = target
    sync()
  }

  function select(item) {
    var at = root.items.indexOf(item)
    if (at < 0) {
      refresh()
      at = root.items.indexOf(item)
    }
    if (at < 0) return
    clearCurrentAction(at)
    root.index = at
    root.cursorActive = true
    sync()
  }

  function move(delta) {
    if (root.customNavigation) { root.moveRequested(0, delta); return }
    if (!root.cursorActive) {
      root.cursorActive = true
      sync()
      return
    }
    setIndex(root.index + delta)
  }

  function activate() {
    if (root.cursorActive && root.current && typeof root.current.activate === "function")
      root.current.activate()
  }

  function adjust(delta) {
    if (root.customNavigation) { root.moveRequested(delta, 0); return }
    if (root.current && typeof root.current.adjust === "function") root.current.adjust(delta)
    else root.horizontalRequested(delta)
  }

  function forget() {
    if (root.cursorActive) root.deleteRequested()
  }

  function takeFocus() {
    root.forceActiveFocus()
    refresh()
    sync()
  }

  function reset(initialIndex) {
    for (var i = 0; i < root.items.length; i++)
      if (typeof root.items[i].clearAction === "function") root.items[i].clearAction()
    root.cursorActive = false
    root.index = initialIndex === undefined ? 0 : Math.max(0, Number(initialIndex) || 0)
    sync()
  }

  onContainerChanged: { root.index = 0; refresh() }
  onIndexChanged: sync()
  onCursorActiveChanged: sync()
  Component.onCompleted: refresh()

  Keys.onPressed: function(event) {
    var handled = true
    var text = event.text || ""
    switch (event.key) {
    case Qt.Key_Down:
      move(1); break
    case Qt.Key_Up:
      move(-1); break
    case Qt.Key_Tab:
      tabRequested((event.modifiers & Qt.ShiftModifier) ? -1 : 1); break
    case Qt.Key_Backtab:
      tabRequested(-1); break
    case Qt.Key_Return:
    case Qt.Key_Enter:
    case Qt.Key_Space:
      activate(); break
    case Qt.Key_Left:
      adjust(-1); break
    case Qt.Key_Right:
      adjust(1); break
    case Qt.Key_Delete:
      forget(); break
    case Qt.Key_Escape:
      canceled(); break
    default:
      if (text === "j" || text === "J") move(1)
      else if (text === "k" || text === "K") move(-1)
      else if (text === "h" || text === "H") adjust(-1)
      else if (text === "l" || text === "L") adjust(1)
      else if (text === "x" || text === "X") forget()
      else if (text.length === 1) textRequested(text)
      else handled = false
    }
    if (handled) event.accepted = true
  }
}
