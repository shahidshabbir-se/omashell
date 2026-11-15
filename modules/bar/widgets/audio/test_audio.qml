import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.modules.bar.widgets.audio

ShellRoot {
  property var service: AudioService
  QtObject {
    id: fake
    property QtObject audio: QtObject { property real volume: 0.5; property bool muted: false }
  }
  AudioPanel { id: panel }
  Timer {
    interval: 2500
    running: true
    onTriggered: {
      AudioService.setVolume(fake, 2, 1)
      AudioService.toggleMute(fake)
      if (fake.audio.volume !== 1 || !fake.audio.muted) {
        console.error('Audio control test failed')
        Qt.exit(1)
        return
      }
      if (Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio && !AudioService.hasOutput) {
        console.error('Default output was not detected')
        Qt.exit(1)
        return
      }
      var rows = AudioService.rows('output')
      for (var i = 0; i < rows.length; i++) {
        if (!AudioService.resolve(rows[i])) {
          console.error('Output snapshot could not be resolved')
          Qt.exit(1)
          return
        }
      }
      panel.open()
      settle.start()
    }
  }
  Timer {
    id: settle
    interval: 800
    onTriggered: {
      console.log('Audio service test passed:', panel.outputs.length, 'outputs,', panel.inputs.length, 'inputs,', panel.streams.length, 'streams')
      panel.close()
      Qt.quit()
    }
  }
}
