import QtQuick
import QtQuick.Shapes
import Quickshell.Io
import qs.common
import qs.config
import "Carousel.js" as Deck

// Omarchy's quattro image picker is the visual reference; this picker uses
// independent local sources and does not rely on its theme services.
OverlayShell {
  id: root

  required property var library
  property var images: []
  property var sidePreviews: ({})
  property var centerPreviews: ({})
  property int selected: 0
  property int session: 0
  property bool browsed: false
  property string active: ""
  property string error: ""
  property bool centerReady: false
  property bool centerFailed: false
  property real wheelDelta: 0
  property int wheelDirection: 0
  readonly property int viewportWidth: width >= 320 ? width : screen?.width || 0
  readonly property int viewportHeight: height >= 200 ? height : screen?.height || 0
  readonly property var layout: Deck.geometry(cardWidth, viewportHeight, viewportWidth / Math.max(1, viewportHeight))
  readonly property string currentKey: images[selected]?.key || ""
  readonly property bool applying: setter.running

  visible: opened
  layerNamespace: "omashell-wallpaper"
  cardChrome: false
  scrimOpacity: centerReady ? 0.72 : 0.35
  cardWidth: Math.min(1840, Math.max(1, viewportWidth - 48))
  padding: 0
  spacing: 14
  focusTarget: carousel
  onDismissed: close()
  onLayoutChanged: if (readyToLayout) syncWindow()
  readonly property bool readyToLayout: viewportWidth > 0 && viewportHeight > 0 && images.length > 0

  function helper(name) {
    return decodeURIComponent(String(Qt.resolvedUrl(name)).replace(/^file:\/\//, ""))
  }

  function toggle() {
    if (opened) { close(); return }
    session++
    browsed = false
    wheelDelta = 0
    wheelDirection = 0
    error = ""
    present()
    syncWindow()
    if (!loader.running) {
      loader.command = ["python3", helper("library.py"), "list", JSON.stringify(library)]
      loader.running = true
    }
    if (!activeQuery.running) {
      activeQuery.session = session
      activeQuery.command = ["python3", helper("library.py"), "active", screen?.name || ""]
      activeQuery.running = true
    }
  }

  function choose(index) {
    if (applying || !images.length) return
    browsed = true
    select(index)
  }

  function select(index) {
    if (selected === index) return
    centerReady = false
    centerFailed = false
    selected = index
    syncWindow()
  }

  function selectActive() {
    if (!opened || browsed || !active) return
    const index = images.findIndex(image => image.path === active || image.canonical === active)
    if (index >= 0) select(index)
  }

  function move(delta) { choose(Deck.wrap(selected + delta, images.length)) }

  function syncWindow() {
    if (!opened || !readyToLayout || (!slots.count && activeQuery.running && !browsed)) return
    Deck.sync(slots, Deck.windowFor(selected, images.length, layout.radius))
    requestPreviews()
  }

  function requestPreviews() {
    if (!opened || !currentKey) return
    if (!centerPreviews[currentKey]) {
      if (!centerWorker.running) centerWorker.start([images[selected]])
      return
    }
    if (sideWorker.running) return
    const visible = Deck.windowFor(selected, images.length, layout.radius)
    const next = visible.filter(row => row.offset !== 0)
      .map(row => images[row.imageIndex]).filter(image => !sidePreviews[image.key])
    if (next.length) sideWorker.start(next.slice(0, 2))
  }

  function cacheResult(tier, result) {
    if (!result.key || !result.url) return
    if (tier === "center") centerPreviews = Object.assign({}, centerPreviews, {[result.key]: result})
    else sidePreviews = Object.assign({}, sidePreviews, {[result.key]: result})
  }

  function applySelected() {
    if (!currentKey || !centerReady || applying || centerFailed) return
    browsed = true
    error = ""
    setter.session = session
    setter.path = images[selected].path
    setter.command = ["python3", helper("library.py"), "apply", setter.path]
    setter.running = true
  }

  Process {
    id: loader
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      if (code !== 0) {
        root.error = stderr.text.trim() || "Could not read the wallpaper library."
        return
      }
      try {
        const previous = root.images[root.selected]?.path || root.active
        const listed = JSON.parse(stdout.text)
        const unchanged = listed.length === root.images.length && listed.every((row, i) =>
          row.key === root.images[i].key && row.path === root.images[i].path)
        if (!unchanged) {
          slots.clear()
          root.centerReady = false
          root.centerFailed = false
          root.images = listed
          root.selected = Math.max(0, root.images.findIndex(image => image.path === previous))
        }
        const side = {}, center = {}
        for (const image of listed) {
          const small = root.sidePreviews[image.key]
          const large = root.centerPreviews[image.key]
          if (image.cached.side) side[image.key] = {url: image.cached.side, fallback: false}
          else if (small?.fallback) side[image.key] = small
          if (image.cached.center) center[image.key] = {url: image.cached.center, fallback: false}
          else if (large?.fallback) center[image.key] = large
        }
        root.sidePreviews = side
        root.centerPreviews = center
        root.selectActive()
        root.syncWindow()
        if (root.opened) carousel.takeFocus()
      } catch (error) {
        root.error = "Could not read the wallpaper list."
      }
    }
  }

  Process {
    id: activeQuery
    property int session: 0
    stdout: StdioCollector {}
    onExited: function(code) {
      if (code === 0 && session === root.session && !root.applying) {
        root.active = stdout.text.replace(/\n$/, "")
        root.selectActive()
      }
      Qt.callLater(root.syncWindow)
    }
  }

  component PreviewWorker: Process {
    id: worker
    required property string tier
    property var requested: []
    function start(entries) {
      requested = entries
      command = ["python3", root.helper("previews.py"), tier, JSON.stringify(entries)]
      running = true
    }
    stdout: SplitParser {
      onRead: function(line) {
        try { root.cacheResult(worker.tier, JSON.parse(line)) } catch (error) {}
      }
    }
    onExited: function(code) {
      const cache = tier === "center" ? root.centerPreviews : root.sidePreviews
      for (const image of requested)
        if (!cache[image.key]) root.cacheResult(tier, {key: image.key, url: image.url, fallback: true})
      requested = []
      Qt.callLater(root.requestPreviews)
    }
  }

  PreviewWorker { id: centerWorker; tier: "center" }
  PreviewWorker { id: sideWorker; tier: "side" }

  Process {
    id: setter
    property int session: 0
    property string path
    stderr: StdioCollector {}
    onExited: function(code) {
      if (code === 0) root.active = path
      if (session !== root.session || !root.opened) return
      if (code === 0) root.close()
      else root.error = stderr.text.trim() || "Could not set wallpaper. Check that awww-daemon is running."
    }
  }

  ListModel { id: slots }

  Item {
    id: carousel
    width: root.cardWidth
    height: Math.ceil(root.layout.centerHeight)
    visible: root.images.length > 0 && root.readyToLayout

    function takeFocus() { forceActiveFocus() }
    Keys.onLeftPressed: root.move(-1)
    Keys.onRightPressed: root.move(1)
    Keys.onTabPressed: root.move(1)
    Keys.onBacktabPressed: root.move(-1)
    Keys.onReturnPressed: root.applySelected()
    Keys.onEnterPressed: root.applySelected()
    WheelHandler {
      target: null
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: function(event) {
        const pixel = event.pixelDelta.x || event.pixelDelta.y
        const angle = event.angleDelta.x || event.angleDelta.y
        const delta = pixel ? pixel / 48 : angle / 120
        if (!delta) return
        const direction = Math.sign(delta)
        if (direction !== root.wheelDirection) root.wheelDelta = 0
        root.wheelDirection = direction
        root.wheelDelta += delta
        const count = Math.trunc(root.wheelDelta)
        if (count) {
          root.wheelDelta -= count
          root.move(-count)
        }
      }
    }

    Repeater {
      model: slots
      delegate: Item {
        id: tile
        required property int imageIndex
        required property int offset
        readonly property var image: root.images[imageIndex]
        readonly property bool selected: offset === 0
        readonly property real bevel: Math.min(26, width / 3)
        readonly property var large: root.centerPreviews[image?.key]
        readonly property var small: root.sidePreviews[image?.key] || (large?.fallback ? null : large)
        readonly property var texture: largeImage.status === Image.Ready ? largeImage
          : smallImage.status === Image.Ready ? smallImage : null
        readonly property bool failed: selected && !texture && largeImage.status === Image.Error

        y: (carousel.height - height) / 2
        z: selected ? 100 : -Math.abs(offset)
        width: selected ? root.layout.centerWidth : root.layout.sliceWidth
        height: selected ? carousel.height : carousel.height * 0.91
        opacity: selected || texture ? 1 : 0
        property int placedOffset: 0
        function place(animate) {
          const target = Deck.xFor(carousel.width, root.layout, offset)
          const slide = animate && root.opened && !root.reduceMotion && offset * placedOffset > 0
            && Math.abs(offset - placedOffset) === 1
          placedOffset = offset
          slideAnimation.stop()
          if (slide) {
            slideAnimation.to = target
            slideAnimation.start()
          } else x = target
        }
        onOffsetChanged: place(true)
        NumberAnimation { id: slideAnimation; target: tile; property: "x"; duration: 135; easing.type: Easing.OutCubic }
        Connections { target: root; function onLayoutChanged() { tile.place(false) } }
        Behavior on opacity { NumberAnimation { duration: root.duration(100) } }
        Accessible.role: Accessible.Button
        Accessible.name: image?.name || ""
        Accessible.onPressAction: activate()
        containmentMask: hitArea
        QtObject {
          id: hitArea
          function contains(point: point): bool {
            return Deck.contains(point.x, point.y, tile.width, tile.height, tile.bevel)
          }
        }

        function updateCenter() {
          if (!selected || image?.key !== root.currentKey) return
          root.centerReady = !!texture
          root.centerFailed = failed
        }
        onSelectedChanged: if (selected) Qt.callLater(updateCenter)
        onTextureChanged: updateCenter()
        onFailedChanged: updateCenter()
        Component.onCompleted: { place(false); updateCenter() }

        function activate() {
          if (selected) root.applySelected()
          else root.choose(imageIndex)
        }

        Image {
          id: smallImage
          visible: false
          source: tile.small?.url || ""
          sourceSize: tile.small?.fallback ? Qt.size(480, 360) : Qt.size(-1, -1)
          asynchronous: true
          autoTransform: true
          onStatusChanged: if (status === Image.Error && tile.small && !tile.small.fallback && tile.image)
            root.cacheResult("side", {key: tile.image.key, url: tile.image.url, fallback: true})
        }
        Image {
          id: largeImage
          visible: false
          source: tile.selected ? tile.large?.url || "" : ""
          sourceSize: tile.large?.fallback ? Qt.size(1600, 1080) : Qt.size(-1, -1)
          asynchronous: true
          autoTransform: true
          onStatusChanged: if (status === Image.Error && tile.large && !tile.large.fallback && tile.image)
            root.cacheResult("center", {key: tile.image.key, url: tile.image.url, fallback: true})
        }

        Shape {
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          TilePath {
            box: tile
            readonly property var texture: tile.texture
            readonly property real tw: Math.max(1, texture?.implicitWidth || 0)
            readonly property real th: Math.max(1, texture?.implicitHeight || 0)
            readonly property real zoom: Math.max(tile.width / tw, tile.height / th)
            fillColor: Colors.lighterBackground
            fillItem: texture
            fillTransform: Qt.matrix4x4(zoom, 0, 0, (tile.width - tw * zoom) / 2,
                                        0, zoom, 0, (tile.height - th * zoom) / 2,
                                        0, 0, 1, 0,
                                        0, 0, 0, 1)
            strokeColor: tile.selected ? Colors.foreground : Colors.accent
            strokeWidth: tile.selected ? 2 : 1
          }
          TilePath {
            box: tile
            fillColor: tile.selected ? "transparent" : Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.30)
            strokeWidth: -1
          }
        }

        Text {
          anchors.centerIn: parent
          visible: tile.selected && !tile.texture
          text: tile.failed ? "Preview unavailable" : "Loading preview…"
          color: Colors.foreground
          font.family: Constants.fontFamily
          font.pixelSize: Constants.fontBody
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: tile.activate() }
      }
    }
  }

  Text {
    width: root.cardWidth
    text: root.error || (root.applying ? "Applying wallpaper…" : root.images.length
      ? `${root.images[root.selected]?.name || ""}  ·  ${root.selected + 1}/${root.images.length}`
      : loader.running ? "Loading wallpapers…" : "No wallpapers found. Add an image or folder in wallpaper.sources.")
    horizontalAlignment: Text.AlignHCenter
    maximumLineCount: 2
    elide: Text.ElideMiddle
    color: Colors.foreground
    font.family: Constants.fontFamily
    font.pixelSize: Constants.fontTitle
    textFormat: Text.PlainText
    wrapMode: Text.WrapAnywhere
    style: Text.Outline
    styleColor: Colors.background
  }

  component TilePath: ShapePath {
    required property Item box
    startX: box.bevel; startY: 0
    PathLine { x: box.width; y: 0 }
    PathLine { x: box.width - box.bevel; y: box.height }
    PathLine { x: 0; y: box.height }
    PathLine { x: box.bevel; y: 0 }
  }

}
