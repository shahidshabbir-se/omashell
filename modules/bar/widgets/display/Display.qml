import QtQuick
import Quickshell
import qs.common
import qs.modules.display

IconWidget {
  id: root

  property var screen: null
  property int wheelRemainder: 0
  readonly property bool builtIn: !!screen && /^(eDP|LVDS|DSI)-/.test(screen.name)

  glyph: Quickshell.screens.length > 1 ? "󰍺" : "󰍹"
  tooltip: "Display"
  Accessible.name: "Display"

  WheelHandler {
    enabled: root.builtIn
    onWheel: function(event) {
      root.wheelRemainder += event.angleDelta.y
      var steps = Math.trunc(root.wheelRemainder / 120)
      if (!steps) return
      root.wheelRemainder -= steps * 120
      Backlight.adjust(steps * 5)
    }
  }
}
