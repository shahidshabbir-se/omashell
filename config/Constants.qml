pragma Singleton
import QtQuick

QtObject {
  readonly property int cornerRadius: 0
  readonly property int barHeight: 28
  readonly property int gap: 5
  readonly property int panelPadding: 14
  // Omarchy panel rows add the theme's rowPaddingX (12px) to their content height.
  readonly property int deviceRowPaddingY: 12

  readonly property string fontFamily: "JetBrainsMono Nerd Font"
  readonly property int fontCaption: 10
  readonly property int fontBodySmall: 11
  readonly property int fontBody: 12
  readonly property int fontSubtitle: 13
  readonly property int fontTitle: 14
  readonly property int fontHeading: 16
  readonly property int fontDisplay: 24

  // Ink height bar icon glyphs are fitted to, so every icon in the bar ends up
  // the same size regardless of what its font metrics say. Matches Omarchy's
  // bar.iconSize (min(iconCanvas 16, icon-size 12)).
  readonly property int iconSize: 12

  // Open-panel mark drawn under a bar widget while its panel is open.
  readonly property int indicatorThickness: 2
  readonly property int indicatorInset: 2

  // Hover dwell before a bar tooltip appears.
  readonly property int tooltipDelay: 400

  // Bar rhythm, the way Omarchy does it: no gap between widgets at all, each
  // widget carries its own horizontal padding instead, so adding, removing or
  // reordering a widget never changes its neighbours' spacing.
  readonly property real barWidgetPadding: 8.5
  // Slot width of an icon-only widget (canvases 21, ink 12): leaves 7.5px of air
  // on either side, which is what a text widget's 8.5 padding looks like next to it.
  readonly property int iconSlot: 27
  // Distance from the screen edge to the first widget.
  readonly property int barSectionMargin: 8

  readonly property int cellWidth: 52
  readonly property int cellHeight: 34
  readonly property int cellSpacing: 2
  readonly property int weekColumnWidth: 32
  readonly property int gutterWidth: 14

  // Compact audio visualizer.
  readonly property int visualizerBarCount: 72
  readonly property int visualizerInputRange: 7
  readonly property real visualizerInputGain: 2.2
  readonly property real visualizerCenterWeight: 0.6
  readonly property real visualizerNeighborWeight: 0.2
  readonly property real visualizerLevelCurve: 0.6
  readonly property real visualizerActivityThreshold: 0.01
  readonly property int visualizerSilenceTimeout: 500
  readonly property int visualizerBarWidth: 5
  readonly property int visualizerBarSpacing: 4
  readonly property int visualizerMaxBarHeight: 54
  readonly property int visualizerMinBarHeight: 2
  readonly property int visualizerBarRadius: 1
  readonly property int visualizerHeight: 72
  readonly property int visualizerBottomMargin: 1
  readonly property int visualizerAnimationDuration: 300
}
