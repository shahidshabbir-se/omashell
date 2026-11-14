pragma Singleton

import QtQuick
import Quickshell.Services.Mpris

QtObject {
    id: root

    readonly property var players: Mpris.players ? Mpris.players.values : []

    readonly property var player: {
        let fallback = null;
        for (let i = 0; i < players.length; i++) {
            const candidate = players[i];
            if (!candidate)
                continue;
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
}
