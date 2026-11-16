import QtQuick
import QtQuick.Controls
import QtQuick.Window
import qs.config

                                                                            
                                                                                  
ToolTip {
  id: root

  property color foreground: Colors.tooltipText
  property color backgroundColor: Colors.tooltipBackground
  property color borderColor: Colors.tooltipBorder
  property string fontFamily: Constants.fontFamily
  property int fontSize: Constants.fontBodySmall

  delay: Constants.tooltipDelay
  padding: 0

  // On Wayland the popup is its own surface, mapped anew on each show. Qt maps
  // it at a whole-number scale before the output's fractional scale arrives, so
  // its first frames are drawn at the wrong size: the border runs off the
  // surface on the right and bottom edges. Hold the bubble transparent until
  // the popup's scale matches the window the tooltip is anchored to. When the
  // popup is an in-window item (no separate surface), both ratios are the same
  // window and the bubble is revealed on the next event loop turn.
  readonly property var popupWindow: background ? background.Window.window : null
  readonly property var anchorWindow: parent && parent.Window && parent.Window.window
    ? parent.Window.window : popupWindow
  readonly property bool scaleReady: visible && popupWindow !== null && anchorWindow !== null
    && Math.round(popupWindow.devicePixelRatio * 120) === Math.round(anchorWindow.devicePixelRatio * 120)

  property bool revealed: false

  // A whole-number output can dip to 1 after its first frame; only hiding may
  // clear the reveal, or the bubble would blink back out mid-show.
  function revealWhenScaled() {
    Qt.callLater(function() {
      if (root.visible && root.scaleReady) root.revealed = true
    })
  }

  onVisibleChanged: {
    if (!visible) {
      revealed = false
      return
    }
    revealWhenScaled()
  }
  onScaleReadyChanged: if (scaleReady) revealWhenScaled()
  Component.onCompleted: if (visible) revealWhenScaled()

  background: Rectangle {
    opacity: root.revealed ? 1 : 0
    color: root.backgroundColor
    border.width: 1
    border.color: root.borderColor
    radius: Constants.cornerRadius
  }

  contentItem: Text {
    opacity: root.revealed ? 1 : 0
    text: root.text
    textFormat: Text.PlainText
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: root.fontSize
    wrapMode: Text.WordWrap
                                                                   
    leftPadding: 11
    rightPadding: 11
    topPadding: 7
    bottomPadding: 7
  }
}
