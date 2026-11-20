import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell.Io
import qs.common
import qs.config

// Omarchy's quattro image picker is the visual reference. This carousel
// uses local files and awww, without Omarchy's theme or background services.
OverlayShell {
  id: root

  required property var library
  readonly property string helper: decodeURIComponent(String(Qt.resolvedUrl("library.py")).replace(/^file:\/\//, ""))
  property var images: []
  property int selected: 0
  property string lastPath: ""
  property string error: ""
  readonly property real previewWidth: Math.min(768, cardWidth * 0.67)
  readonly property real previewHeight: Math.min(475, height * 0.65)
  readonly property real sliceWidth: Math.max(36, previewWidth * 0.14)
  readonly property real step: sliceWidth * 0.73

  visible: opened
  layerNamespace: "omashell-wallpaper"
  cardChrome: false
  cardWidth: Math.min(1820, Math.max(1, width - 40))
  padding: 0
  spacing: 12
  focusTarget: carousel
  onDismissed: close()

  function toggle() {
    if (opened) close()
    else {
      error = ""
      present()
      if (!loader.running) {
        loader.command = ["python3", helper, "list", JSON.stringify(library)]
        loader.running = true
      }
    }
  }

  function move(delta) {
    if (images.length) selected = (selected + delta + images.length) % images.length
  }

  function applySelected() {
    if (!images.length || setter.running) return
    error = ""
    setter.path = images[selected].path
    setter.command = ["python3", helper, "apply", setter.path]
    setter.running = true
  }

  Process {
    id: loader
    stdout: StdioCollector {}
    stderr: StdioCollector {}
    onExited: function(code) {
      if (code !== 0) {
        root.images = []
        root.error = stderr.text.trim() || "Could not open the wallpaper folder."
        return
      }
      try {
        const previous = root.images[root.selected]?.path || root.lastPath
        root.images = JSON.parse(stdout.text)
        root.selected = Math.max(0, root.images.findIndex(image => image.path === previous))
        if (root.opened && root.images.length) carousel.takeFocus()
      } catch (error) {
        root.images = []
        root.error = "Could not read the wallpaper list."
      }
    }
  }

  Process {
    id: setter
    property string path
    stderr: StdioCollector {}
    onExited: function(code) {
      if (code === 0) {
        root.lastPath = path
        root.close()
      } else root.error = stderr.text.trim() || "Could not set wallpaper. Check that awww-daemon is running."
    }
  }

  Item {
    id: carousel
    width: root.cardWidth
    height: root.images.length ? root.previewHeight : 0
    visible: height > 0
    clip: true

    function takeFocus() { forceActiveFocus() }
    Keys.onLeftPressed: root.move(-1)
    Keys.onRightPressed: root.move(1)
    Keys.onTabPressed: root.move(1)
    Keys.onBacktabPressed: root.move(-1)
    Keys.onReturnPressed: root.applySelected()
    Keys.onEnterPressed: root.applySelected()
    WheelHandler {
      target: null
      onWheel: function(event) {
        const delta = event.angleDelta.x || event.angleDelta.y
        if (delta) root.move(delta > 0 ? -1 : 1)
      }
    }

    Repeater {
      model: {
        if (!root.opened || !root.images.length) return []
        const radius = Math.ceil((carousel.width - root.previewWidth) / (2 * root.step)) + 1
        const first = Math.max(0, root.selected - radius)
        const end = Math.min(root.images.length, root.selected + radius + 1)
        return Array.from({ length: end - first }, (_, offset) => first + offset)
      }

      delegate: Item {
        id: tile
        required property int modelData
        readonly property int indexInLibrary: modelData
        readonly property var image: root.images[indexInLibrary]
        readonly property int offset: indexInLibrary - root.selected
        readonly property bool selected: offset === 0
        readonly property real bevel: Math.min(28, width / 3)
        readonly property real centerLeft: (carousel.width - root.previewWidth) / 2
        x: selected ? centerLeft : offset < 0 ? centerLeft + offset * root.step
          : centerLeft + root.previewWidth - root.sliceWidth + offset * root.step
        y: (carousel.height - height) / 2
        z: selected ? 100 : -Math.abs(offset)
        width: selected ? root.previewWidth : root.sliceWidth
        height: selected ? carousel.height : carousel.height * 0.91
        Accessible.role: Accessible.Button
        Accessible.name: image?.name || ""
        Accessible.onPressAction: activate()

        function activate() {
          if (selected) root.applySelected()
          else root.selected = indexInLibrary
        }

        Silhouette {
          id: mask
          anchors.fill: parent
          bevel: tile.bevel
          visible: false
          layer.enabled: true
          fill: "white"
        }

        Item {
          anchors.fill: parent
          layer.enabled: true
          layer.effect: MultiEffect { maskEnabled: true; maskSource: mask }

          Rectangle { anchors.fill: parent; color: Colors.lighterBackground }
          Image {
            anchors.fill: parent
            source: tile.image?.url || ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(Math.ceil(root.previewWidth), Math.ceil(root.previewHeight))
            asynchronous: true
            cache: false
          }
          Rectangle {
            anchors.fill: parent
            color: Colors.background
            opacity: tile.selected ? 0 : 0.42
          }
        }

        Silhouette {
          anchors.fill: parent
          bevel: tile.bevel
          stroke: tile.selected ? Colors.foreground : Colors.accent
          strokeWidth: tile.selected ? 3 : 1
        }

        HoverHandler { cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: tile.activate() }
      }
    }
  }

  Text {
    width: root.cardWidth
    text: root.error || (root.images.length ? root.images[root.selected]?.name || "" :
      loader.running ? "" : "No wallpapers found. Add an image or folder in wallpaper.sources.")
    visible: text !== ""
    horizontalAlignment: Text.AlignHCenter
    color: Colors.foreground
    font.family: Constants.fontFamily
    font.pixelSize: Constants.fontTitle
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    style: Text.Outline
    styleColor: Colors.background
  }

  component Silhouette: Shape {
    id: shape
    property real bevel
    property color fill: "transparent"
    property color stroke: "transparent"
    property real strokeWidth: 0
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
      fillColor: shape.fill
      strokeColor: shape.stroke
      strokeWidth: shape.strokeWidth
      startX: shape.bevel; startY: 0
      PathLine { x: shape.width; y: 0 }
      PathLine { x: shape.width - shape.bevel; y: shape.height }
      PathLine { x: 0; y: shape.height }
      PathLine { x: shape.bevel; y: 0 }
    }
  }
}
