import QtQuick
import qs.config

// Bar icon glyph, centred on its painted outline instead of on its line box.
//
// A Nerd Font icon has no predictable figure metrics, so font metrics say nothing
// useful about where its ink is. Instead the glyph's tight ink rect is measured,
// fitted to `paintedSize` and the outline's centre is placed on the box's centre.
//
// contents of paintedSize 0 keeps the plain line-box centring, for labels that
// only happen to live in this component.
Item {
  id: root

  property string text: ""
  property string fontFamily: Constants.fontFamily
  property real fontSize: Constants.fontBody
  // Ink height to fit the glyph to. 0 falls back to line-box centring.
  property real paintedSize: 0
  property color color: Colors.foreground

  readonly property int renderedFontSize: Math.max(1, Math.round(fontSize))

  // Tight bounds come back in whole pixels, which at bar sizes adds up to a pixel
  // of ink that isn't there and shifts the glyph's centre. Measuring a hundred
  // times larger keeps them to the outline.
  readonly property int metricsScale: 100
  readonly property rect ink: Qt.rect(
    metrics.tightBoundingRect.x / metricsScale,
    metrics.tightBoundingRect.y / metricsScale,
    metrics.tightBoundingRect.width / metricsScale,
    metrics.tightBoundingRect.height / metricsScale)
  readonly property real tightWidth: Math.max(1, ink.width)
  readonly property real tightHeight: Math.max(1, ink.height)

  readonly property real paintedScale: paintedSize > 0
    // Fit the ink *height* to paintedSize, not its longest side: a wide, flat
    // glyph fitted by its width ends up shorter than a square one and reads as
    // a smaller icon next to it. Clamped so a wide glyph still fits the box.
    ? Math.min(paintedSize / tightHeight, width / tightWidth, height / tightHeight)
    : 1
  readonly property real paintedWidth: tightWidth * paintedScale
  readonly property real paintedHeight: tightHeight * paintedScale
  readonly property real paintedCenterX: glyph.x + (ink.x + tightWidth / 2) * paintedScale
  readonly property real paintedCenterY: glyph.y
    + (glyph.baselineOffset + ink.y + tightHeight / 2) * paintedScale
  readonly property real baselineY: glyph.y + glyph.baselineOffset * paintedScale

  TextMetrics {
    id: metrics
    font.family: root.fontFamily
    font.pixelSize: root.renderedFontSize * root.metricsScale
    text: root.text
  }

  Text {
    id: glyph

    text: root.text
    textFormat: Text.PlainText
    color: root.color
    font.family: root.fontFamily
    font.pixelSize: root.renderedFontSize
    transformOrigin: Item.TopLeft
    scale: root.paintedScale
    // The ink rect is expressed against the baseline, so baselineOffset is part
    // of the vertical placement; without it the glyph lands an ascent too high.
    x: root.width / 2 - (root.ink.x + root.tightWidth / 2) * root.paintedScale
    y: root.paintedSize > 0
      ? root.height / 2 - (baselineOffset + root.ink.y + root.tightHeight / 2) * root.paintedScale
      : Math.round((root.height - height) / 2)
    // Scaled icons use distance fields: at bar sizes the curve renderer's
    // antialiasing overshoots where a corner meets a straight edge, so the flat
    // top of a rounded square steps up at its ends.
    renderType: root.paintedSize > 0 ? Text.QtRendering : Text.NativeRendering
  }
}
