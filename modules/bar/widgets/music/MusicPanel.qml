import QtQuick
import QtQuick.Layouts
import qs.common
import qs.config
import qs.modules.bar.widgets.music

PanelShell {
  id: root
  layerNamespace: "omashell-music"
  cardWidth: 300
  contentPadding: 0
  property bool entranceReady: false
  onOpenedChanged: {
    entranceReady = false
    if (opened) Qt.callLater(function() { if (root.opened) root.entranceReady = true })
  }

  MprisPlaybackSession { id: playback }

  Item {
    width: parent.width
    implicitHeight: Math.max(496, content.implicitHeight + Constants.panelPadding * 2)

    MusicBackdrop {
      anchors.fill: parent
      artworkSource: playback.artworkSource
      entranceReady: root.entranceReady
      active: playback.hasCurrentPlayback
    }

    ColumnLayout {
      id: content
      x: Constants.panelPadding
      width: Math.max(0, parent.width - Constants.panelPadding * 2)
      height: Math.max(0, parent.height - Constants.panelPadding * 2)
      spacing: 0
      opacity: root.entranceReady ? 1 : 0
      y: Constants.panelPadding + (root.entranceReady ? 0 : 10)
      Behavior on opacity { NumberAnimation { duration: 167; easing.type: Easing.OutCubic } }
      Behavior on y { NumberAnimation { duration: 167; easing.type: Easing.OutCubic } }

      NowPlayingHero {
        Layout.fillWidth: true
        playback: playback
        entranceReady: root.entranceReady
        panelOpen: root.opened
      }
      Item { Layout.preferredHeight: MusicStyle.spacingLg }
      TrackProgress { Layout.fillWidth: true; playback: playback }
      Item { Layout.preferredHeight: MusicStyle.spacingSm }
      PlaybackControls { Layout.fillWidth: true; playback: playback; entranceReady: root.entranceReady }
      Item { Layout.preferredHeight: MusicStyle.spacingXl }
      VolumeControl { Layout.fillWidth: true; playback: playback }
    }
  }
}
