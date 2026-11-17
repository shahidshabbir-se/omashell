pragma Singleton
import QtQuick
import qs.config

QtObject {
  readonly property int musicArtworkSize: 255
  readonly property int musicControlSize: 36
  readonly property int musicPrimaryControlSize: 40
  readonly property int fontSizeLg: Constants.fontTitle
  readonly property int fontSizeMd: Constants.fontBody
  readonly property int fontSizeXl: 18
  readonly property int iconSizeLg: 16
  readonly property int spacingXs: 4
  readonly property int spacingSm: 6
  readonly property int spacingMd: 8
  readonly property int spacingLg: 12
  readonly property int spacingXl: 16
  readonly property color foregroundStrong: Colors.brightForeground
  readonly property color foregroundQuiet: Colors.darkForeground
  readonly property color backgroundDeep: Colors.darkerBackground
  readonly property color backgroundRaised: Colors.lighterBackground
  readonly property color selectionSurface: Colors.selection
  readonly property color accentHover: Colors.brightBlue

  function withAlpha(color, alpha) {
    return Qt.rgba(color.r, color.g, color.b, alpha)
  }
}
