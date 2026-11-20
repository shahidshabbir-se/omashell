// THROWAWAY PERFORMANCE PROTOTYPE: deterministic comparison, not production.
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

ShellRoot {
  id: root
  readonly property string mode: Quickshell.env('VISUALIZER_PROTOTYPE_MODE') || 'current'
  readonly property bool optimized: mode === 'optimized'
  readonly property bool compact: mode === 'compact' || optimized
  readonly property bool reducedRate: mode === 'rate30' || optimized
  readonly property int count: 72
  property int frame: 0
  property var levels: Array(72).fill(0)

  Timer {
    interval: root.reducedRate ? 33 : 16
    running: root.mode !== 'baseline'
    repeat: true
    onTriggered: {
      var values = []
      var t = root.frame++ / (root.reducedRate ? 30 : 60)
      for (var i = 0; i < root.count; i++)
        values.push(0.1 + 0.8 * Math.abs(Math.sin(i * 0.21 + t * 3) * Math.cos(i * 0.09 - t * 1.2)))
      root.levels = values
    }
  }
  PanelWindow {
    id: panel
    screen: Quickshell.screens.length ? Quickshell.screens[0] : null
    visible: root.mode !== 'baseline' && screen !== null
    anchors.bottom: true
    anchors.left: !root.compact
    anchors.right: !root.compact
    implicitWidth: root.count * 9 - 4
    implicitHeight: 72
    margins.bottom: 1
    exclusionMode: ExclusionMode.Ignore
    aboveWindows: false
    focusable: false
    color: 'transparent'
    mask: Region {}
    Item {
      anchors.centerIn: parent
      width: root.count * 9 - 4
      height: 54
      Repeater {
        model: root.count
        Rectangle {
          required property int index
          x: index * 9
          anchors.bottom: parent.bottom
          width: 5
          height: Math.max(2, root.levels[index] * 54)
          radius: 1
          gradient: Gradient {
            GradientStop { position: 0; color: '#7aa2f7' }
            GradientStop { position: 1; color: '#ad8ee6' }
          }
          Behavior on height {
            enabled: !root.optimized
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
          }
        }
      }
    }
  }
}
