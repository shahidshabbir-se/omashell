import QtQuick
import qs.config

// Text whose figures sit on the middle of its box instead of on the middle of its
// line box.
//
// Qt reserves descender space below every baseline, and digits never use it, so
// centring a *Text*'s line box leaves the visible figures slightly above the
// middle. The offset below is exactly how far off they are: half of
// (descent - ascent + figure height), measured from font metrics rather than guessed.
//
// Use this anywhere a bar widget shows text (clock, workspace numbers). It is a
// drop-in for Text: bind `text`, set `pixelSize`, anchor it where the old Text was.
Item {
  id: root

  // Off for icon-font labels, whose figure metrics say nothing about the glyph.
  property bool centerFigures: true
  property string fontFamily: Constants.fontFamily
  property int pixelSize: Constants.fontBody
  property color color: Colors.foreground
  property alias text: label.text

  implicitWidth: label.implicitWidth
  implicitHeight: label.implicitHeight

  // Reference figure for the offset. "0" is the tallest digit with neither
  // ascender nor descender overshoot.
  readonly property real figureOffset: (metrics.descent - metrics.ascent
    + metrics.tightBoundingRect("0").height) / 2

  FontMetrics {
    id: metrics
    font: label.font
  }

  Text {
    id: label

    anchors.centerIn: parent
    // Multi-line labels are stacked, so no figure correction applies.
    anchors.verticalCenterOffset: root.centerFigures && label.text.indexOf("\n") === -1
      ? root.figureOffset
      : 0

    textFormat: Text.PlainText
    renderType: Text.NativeRendering
    font.family: root.fontFamily
    font.pixelSize: root.pixelSize
    color: root.color
  }
}
