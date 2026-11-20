/*
The volume OSD design and layout are adapted from the Omarchy shell:
https://github.com/omacom/omarchy/tree/quattro/shell/plugins/osd

Copyright (c) David Heinemeier Hansson

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config

PanelWindow {
  id: root
  property var output: null
  property bool opened: false
  property var display: ({ percent: 0, progress: 0, icon: '', label: '0%' })
  readonly property int padding: 16
  readonly property int gap: 16
  readonly property int barWidth: 142
  readonly property int iconWidth: Math.ceil(Math.max(iconMetrics.tightBoundingRect.width, widestIconMetrics.tightBoundingRect.width))
  readonly property int valueWidth: Math.ceil(Math.max(valueMetrics.advanceWidth, labelMetrics.advanceWidth))

  screen: output
  visible: opened && output !== null
  color: 'transparent'
  implicitWidth: 4 + padding * 2 + iconWidth + gap * 2 + barWidth + valueWidth
  implicitHeight: 4 + padding * 2 + 28
  anchors.bottom: true
  margins.bottom: 67
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: 'omashell-volume-osd'
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  mask: Region {}

  TextMetrics { id: iconMetrics; font.family: Constants.fontFamily; font.pixelSize: 28; text: root.display.icon }
  TextMetrics { id: widestIconMetrics; font: iconMetrics.font; text: '' }
  TextMetrics { id: valueMetrics; font.family: Constants.fontFamily; font.pixelSize: Constants.fontTitle; font.bold: true; text: '100%' }
  TextMetrics { id: labelMetrics; font: valueMetrics.font; text: root.display.label }

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(Colors.background.r, Colors.background.g, Colors.background.b, 0.97)
    border.width: 2
    border.color: Colors.accent
    radius: Constants.cornerRadius

    Row {
      anchors.fill: parent
      anchors.margins: root.padding + 2
      spacing: root.gap
      Item {
        width: root.iconWidth
        height: parent.height
        Text {
          x: Math.round((root.iconWidth - iconMetrics.tightBoundingRect.width) / 2 - iconMetrics.tightBoundingRect.x)
          anchors.verticalCenter: parent.verticalCenter
          text: root.display.icon
          font: iconMetrics.font
          color: Colors.foreground
        }
      }
      Rectangle {
        width: root.barWidth
        height: 6
        anchors.verticalCenter: parent.verticalCenter
        color: Qt.rgba(Colors.foreground.r, Colors.foreground.g, Colors.foreground.b, 0.45)
        Rectangle {
          height: parent.height
          width: parent.width * root.display.progress
          color: Colors.accent
          Behavior on width {
            enabled: root.opened
            NumberAnimation { duration: 140; easing.type: Easing.OutCubic }
          }
        }
      }
      Text {
        width: root.valueWidth
        anchors.verticalCenter: parent.verticalCenter
        horizontalAlignment: Text.AlignRight
        text: root.display.label
        font: valueMetrics.font
        color: Colors.foreground
      }
    }
  }
}
