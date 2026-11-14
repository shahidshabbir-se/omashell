import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Small shared output state for the existing volume OSD. The Omarchy audio
// panel owns its richer input/output/stream model independently.
Scope {
    id: root

    property bool panelOpen: false
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property bool available: Pipewire.ready && !!sink?.ready && !!sink?.audio && sink.audio.channels.length > 0
    readonly property real volume: available ? sink.audio.volume : 0
    readonly property bool muted: available ? sink.audio.muted : false
    readonly property string icon: !available || muted || volume <= 0 ? ""
        : volume >= 0.67 ? "" : volume >= 0.34 ? "" : ""

    function setVolume(value) {
        if (available && Number.isFinite(value))
            sink.audio.volume = Math.max(0, Math.min(1.5, value))
    }

    function toggleMute() {
        if (available) sink.audio.muted = !muted
    }
}
