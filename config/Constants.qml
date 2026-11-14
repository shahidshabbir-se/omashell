pragma Singleton
import QtQuick

QtObject {
  readonly property int cornerRadius: 0
  readonly property int barHeight: 28
  readonly property int gap: 5
  readonly property int popupPadding: 14

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

  readonly property int cellWidth: 52
  readonly property int cellHeight: 34
  readonly property int cellSpacing: 2
  readonly property int weekColumnWidth: 32
  readonly property int gutterWidth: 14
}
