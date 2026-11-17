import QtQuick
import Quickshell
import qs.modules.bar
import qs.modules.bar.widgets.music

ShellRoot {
  MprisPlaybackSession { id: session }
  MusicButton { id: button }
  NowPlayingHero { playback: session; entranceReady: true; panelOpen: false }
  PlaybackControls { playback: session; entranceReady: true }
  TrackProgress { playback: session }
  VolumeControl { playback: session }
  MusicBackdrop { artworkSource: session.artworkSource; entranceReady: true; active: false }

  Timer {
    interval: 200
    running: true
    onTriggered: {
      var ok = WidgetRegistry.known("music") &&
        String(WidgetRegistry.urlFor("music")).indexOf("MusicButton.qml") >= 0 &&
        button.widgetId !== undefined && button.settings !== undefined &&
        button.available === MusicRuntime.hasCurrentPlayback
      console.log(ok ? "TEST PASS" : "TEST FAIL")
      Qt.exit(ok ? 0 : 1)
    }
  }
}
