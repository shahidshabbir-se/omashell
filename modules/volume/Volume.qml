import QtQuick
import Quickshell
import Quickshell.Hyprland
import "../../config"

Scope {
    id: root

    property var audioRuntime
    readonly property var sink: audioRuntime ? audioRuntime.sink : null
    readonly property bool available: !!audioRuntime && audioRuntime.available
    readonly property real volume: audioRuntime ? audioRuntime.volume : 0
    readonly property bool muted: audioRuntime ? audioRuntime.muted : false

    property var popupScreen: null
    property bool open: false
    property var observedSink: null
    property real previousVolume: 0
    property bool previousMuted: false

    function dismiss() {
        open = false;
        hideTimer.stop();
    }

    function observe() {
                                                                                  
        if (!available) {
            observedSink = null;
            dismiss();
            return;
        }
        const nextVolume = sink.audio.volume;
        const nextMuted = sink.audio.muted;
        const changed = observedSink === sink
            && (previousVolume !== nextVolume || previousMuted !== nextMuted);
        if (observedSink !== sink)
            dismiss();
                                                                          
        observedSink = sink;
        previousVolume = nextVolume;
        previousMuted = nextMuted;
        if (changed)
            pulse();
    }

    function pulse() {
        if (!available)
            return;
        if (!open) {
            const focused = Hyprland.focusedMonitor?.name;
            popupScreen = Quickshell.screens.find(screen => screen.name === focused)
                ?? Quickshell.screens[0] ?? null;
        }
        open = popupScreen !== null;
        if (!flyer.hovered)
            hideTimer.restart();
    }

    function toggleMute() {
        if (available)
            audioRuntime.toggleMute();
    }

    function nudge(delta) {
        if (!available || muted || !Number.isFinite(delta))
            return;
        audioRuntime.setVolume(Math.max(0, Math.min(Constants.volumeMaximum, volume + delta)));
    }

    onSinkChanged: observe()
    onAvailableChanged: observe()
                                                                               
                                                                                
    onVolumeChanged: observe()
    onMutedChanged: observe()
    Component.onCompleted: observe()

    Connections {
        target: Quickshell
        function onScreensChanged() {
            if (!Quickshell.screens.includes(root.popupScreen)) {
                root.dismiss();
                root.popupScreen = null;
            }
        }
    }

    Timer {
        id: hideTimer
        interval: Constants.volumeHideMs
        onTriggered: root.open = false
    }

    VolumeFlyer {
        id: flyer
        output: root.popupScreen
        open: root.open && root.available
        volume: root.volume
        muted: root.muted
        onHoveredChanged: {
            if (hovered)
                hideTimer.stop();
            else if (root.open)
                hideTimer.restart();
        }
        onToggleMute: root.toggleMute()
        onNudge: delta => root.nudge(delta)
    }
}
