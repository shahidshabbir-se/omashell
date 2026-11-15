pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import 'Model.js' as Model

QtObject {
  id: root
  readonly property var sink: Pipewire.defaultAudioSink
  readonly property var source: Pipewire.defaultAudioSource
  readonly property var nodes: Pipewire.nodes ? Pipewire.nodes.values : []
  readonly property var tracked: {
    var result = []
    for (var i = 0; i < nodes.length; i++) {
      var n = nodes[i]
      if (!n) continue
      if ((!n.isStream && (n.isSink || n.type === PwNodeType.AudioSource)) || (n.isStream && n.isSink)) result.push(n)
    }
    return result
  }
  readonly property real outputVolume: sink && sink.audio ? sink.audio.volume : 0
  readonly property bool outputMuted: !!(sink && sink.audio && sink.audio.muted)
  readonly property real inputVolume: source && source.audio ? source.audio.volume : 0
  readonly property bool inputMuted: !!(source && source.audio && source.audio.muted)
  readonly property bool hasOutput: !!(sink && sink.audio)
  readonly property bool hasInput: !!(source && source.audio)
  readonly property bool anyAudible: (hasOutput && !outputMuted) || (hasInput && !inputMuted)
  readonly property string icon: Model.volumeIcon(hasOutput ? sink : null, outputVolume, outputMuted)
  readonly property string caption: Model.volumeName(outputVolume, outputMuted)
  property var outputAvailability: ({})
  property PwObjectTracker tracker: PwObjectTracker { objects: root.tracked }

  function setVolume(node, volume, maximum) {
    if (node && node.audio) node.audio.volume = Model.clamp(volume, maximum)
  }
  function toggleMute(node) { if (node && node.audio) node.audio.muted = !node.audio.muted }
  function toggleAll() {
    var mute = anyAudible
    if (hasOutput) sink.audio.muted = mute
    if (hasInput) source.audio.muted = mute
  }
  function selectDevice(row, input) {
    var node = Model.findNode(nodes, row)
    if (!node || node.isStream) return
    if (input && node.audio) Pipewire.preferredDefaultAudioSource = node
    else if (!input && node.isSink) Pipewire.preferredDefaultAudioSink = node
    else return
    Quickshell.execDetached(['wpctl', 'set-default', String(node.id)])
  }
  function resolve(row) { return Model.findNode(nodes, row) }
  function rows(kind) {
    return Model.snapshot(nodes, function(n) {
      if (kind === 'output') return !n.isStream && n.isSink && !!n.audio
        && (root.outputAvailability[String(n.name)] !== false || (root.sink && n.id === root.sink.id))
      if (kind === 'input') return !n.isStream && !n.isSink && n.type === PwNodeType.AudioSource && !!n.audio
      return n.isStream && n.isSink && !!n.audio
    })
  }
}
