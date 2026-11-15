import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

QtObject {
    id: root

    readonly property var player: {
        let fallback = null;

        for (let i = 0; i < Mpris.players.values.length; i++) {
            const candidate = Mpris.players.values[i];

            if (candidate.isPlaying)
                return candidate;

            if (!fallback || candidate.identity.toLowerCase().includes("spotify"))
                fallback = candidate;
        }

        return fallback;
    }

    readonly property bool hasPlayer: player !== null
    readonly property bool hasCurrentPlayback: hasPlayer && player.playbackState !== MprisPlaybackState.Stopped
    readonly property bool isPlaying: hasPlayer && player.isPlaying

    readonly property string title: hasPlayer ? (player.trackTitle || "Unknown title") : "Nothing playing"
    readonly property string artist: hasPlayer ? (player.trackArtist || "Unknown artist") : "Start a player to see media here"
    readonly property url fallbackArtwork: Qt.resolvedUrl("assets/artwork/music-fallback.svg")
    readonly property url artworkSource: hasPlayer && player.trackArtUrl ? player.trackArtUrl : fallbackArtwork

    readonly property real positionSeconds: hasPlayer ? player.position : 0
    readonly property real durationSeconds: hasPlayer && player.lengthSupported ? player.length : 0
    readonly property real progress: durationSeconds > 0 ? Math.min(1, Math.max(0, positionSeconds / durationSeconds)) : 0

    readonly property bool canSeek: hasPlayer && player.canSeek && player.positionSupported && durationSeconds > 0
    readonly property bool canGoPrevious: hasPlayer && player.canGoPrevious
    readonly property bool canTogglePlaying: hasPlayer && player.canTogglePlaying
    readonly property bool canGoNext: hasPlayer && player.canGoNext

    readonly property bool shuffleSupported: hasPlayer && player.shuffleSupported
    readonly property bool canToggleShuffle: shuffleSupported && player.canControl
    readonly property bool shuffleActive: shuffleSupported && player.shuffle

    readonly property bool loopSupported: hasPlayer && player.loopSupported
    readonly property bool canToggleLoop: loopSupported && player.canControl
    readonly property bool loopActive: loopSupported && player.loopState !== MprisLoopState.None

                                                                       
    readonly property var pipewireNodes: Pipewire.nodes ? Pipewire.nodes.values : []
                                                                            
                                                                
    property PwObjectTracker pipewireNodeTracker: PwObjectTracker {
        objects: root.pipewireNodes.filter(node => node && node.isStream && node.isSink)
    }
    property PwObjectTracker sinkTracker: PwObjectTracker {
        objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : []
    }

    function isPlaybackStream(node) {
        return !!(node && node.isStream && node.isSink);
    }

                                                                        
    readonly property var matchedStreamNode: {
        if (!hasPlayer)
            return null;

        const nodes = pipewireNodes;
        const identity = String(root.player.identity || "").toLowerCase();
        const key = identity.replace(/[^a-z0-9]+/g, "");
        if (key.length >= 3) {
            for (let i = 0; i < nodes.length; i++) {
                const node = nodes[i];
                if (!isPlaybackStream(node))
                    continue;
                const props = node.properties || {};
                const nodeKey = String(node.name || "").toLowerCase().replace(/[^a-z0-9]+/g, "");
                const appKey = String(props["application.name"] || props["application.process.binary"] || "").toLowerCase().replace(/[^a-z0-9]+/g, "");
                if ((nodeKey && (nodeKey.includes(key) || key.includes(nodeKey))) || (appKey && (appKey.includes(key) || key.includes(appKey))))
                    return node;
            }
        }

        for (let i = 0; i < nodes.length; i++) {
            const node = nodes[i];
            if (isPlaybackStream(node))
                return node;
        }

        return null;
    }

                                                                            
                                                                          
                                                                              
    readonly property bool mprisVolumeAvailable: hasPlayer && player.volumeSupported
    readonly property var volumeStreamNode: matchedStreamNode && matchedStreamNode.audio && matchedStreamNode.bound ? matchedStreamNode : null
    readonly property real volumeMaximum: volumeStreamNode ? 1.5 : 1
    readonly property bool canSetVolume: volumeStreamNode !== null || mprisVolumeAvailable
    readonly property real volume: volumeStreamNode ? Math.max(0, Math.min(volumeMaximum, volumeStreamNode.audio.volume)) : (mprisVolumeAvailable ? Math.max(0, Math.min(1, player.volume)) : 0)

    function seekTo(normalizedPosition) {
        if (!canSeek)
            return;
        player.position = Math.min(1, Math.max(0, normalizedPosition)) * durationSeconds;
    }

    function goPrevious() {
        if (canGoPrevious)
            player.previous();
    }

    function togglePlaying() {
        if (canTogglePlaying)
            player.togglePlaying();
    }

    function goNext() {
        if (canGoNext)
            player.next();
    }

    function toggleShuffle() {
        if (canToggleShuffle)
            player.shuffle = !player.shuffle;
    }

    function toggleLoop() {
        if (!canToggleLoop)
            return;
        player.loopState = player.loopState === MprisLoopState.None ? MprisLoopState.Playlist : MprisLoopState.None;
    }

    function setVolume(normalizedVolume) {
        const val = Math.min(1, Math.max(0, normalizedVolume));

        if (volumeStreamNode) {
                                                                              
            volumeStreamNode.audio.volume = Math.min(volumeMaximum, val);
            return;
        }

                                                                          
                                                                               
        if (mprisVolumeAvailable)
            player.volume = Math.min(1, val);
    }

    property Timer positionRefreshTimer: Timer {
        interval: 500
        repeat: true
        running: root.isPlaying

        onTriggered: root.player.positionChanged()
    }
}
