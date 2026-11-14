pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import "../../../../config"

ColumnLayout {
    id: root

    required property var playback

    spacing: Constants.spacingXs

    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0)
            seconds = 0;

        const total = Math.floor(seconds);
        const minutes = Math.floor(total / 60);
        const remainder = total % 60;

        return minutes + ":" + (remainder < 10 ? "0" : "") + remainder;
    }

    Item {
        id: slider

        Layout.fillWidth: true
        implicitHeight: 20

        readonly property real barHeight: 4
        readonly property real gap: 4
        readonly property real stopSize: 4

        property bool dragging: false
        property real dragFraction: 0

        readonly property real fraction: dragging ? dragFraction : (root.playback.durationSeconds > 0 ? root.playback.progress : 0)
        readonly property real activeWidth: Math.round(fraction * width)
        readonly property bool interactive: root.playback.canSeek

        function fractionAt(xPosition) {
            return Math.min(1, Math.max(0, xPosition / Math.max(1, width)));
        }

        // Remaining track: starts one gap after the active indicator and stops before the end dot
        Rectangle {
            id: remainingTrack
            x: Math.min(slider.width, slider.activeWidth + slider.gap)
            width: Math.max(0, slider.width - x - slider.stopSize - slider.gap)
            height: slider.barHeight
            radius: height / 2
            anchors.verticalCenter: parent.verticalCenter
            color: Colors.withAlpha(Colors.foreground, 0.22)
        }

        // Stop dot parked at the far end of the track
        Rectangle {
            id: stopDot
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: slider.stopSize
            height: slider.stopSize
            radius: width / 2
            color: Colors.accent
            opacity: slider.interactive ? 1.0 : 0.45
        }

        // Material 3 Expressive animated wiggle wave
        Canvas {
            id: wave
            anchors.fill: parent
            antialiasing: true

            property real phase: 0
            readonly property bool active: root.playback.isPlaying
            property real amplitude: active ? 3.0 : 0.0
            readonly property real wavelength: 20.0

            Behavior on amplitude {
                NumberAnimation {
                    duration: 260
                    easing.type: Easing.OutCubic
                }
            }

            NumberAnimation on phase {
                running: true
                paused: !wave.active
                loops: Animation.Infinite
                from: 0
                to: 2 * Math.PI
                duration: 1400
                easing.type: Easing.Linear
            }

            onPhaseChanged: requestPaint()
            onAmplitudeChanged: requestPaint()

            Connections {
                target: slider
                function onActiveWidthChanged() {
                    wave.requestPaint();
                }
            }

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();

                const mid = height / 2;
                const h = slider.barHeight;
                const end = slider.activeWidth;

                if (end <= 0)
                    return;
                ctx.lineWidth = h;
                ctx.lineCap = "round";
                ctx.lineJoin = "round";
                ctx.strokeStyle = Colors.accent;
                ctx.beginPath();

                // Taper the wave near the end so the head meets the gap smoothly
                const taper = Math.max(1, wave.wavelength);
                for (let x = 0; x <= end; x += 1) {
                    const fade = Math.min(1, (end - x) / taper);
                    const y = mid + wave.amplitude * fade * Math.sin((x / wave.wavelength) * 2 * Math.PI + wave.phase);
                    if (x === 0)
                        ctx.moveTo(x, y);
                    else
                        ctx.lineTo(x, y);
                }
                ctx.stroke();
            }
        }

        MouseArea {
            id: pointer
            anchors.fill: parent
            enabled: slider.interactive
            cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            preventStealing: true

            onPressed: mouse => {
                slider.dragFraction = slider.fractionAt(mouse.x);
                slider.dragging = true;
            }

            onPositionChanged: mouse => {
                if (slider.dragging)
                    slider.dragFraction = slider.fractionAt(mouse.x);
            }

            onReleased: mouse => {
                slider.dragFraction = slider.fractionAt(mouse.x);
                root.playback.seekTo(slider.dragFraction);
                slider.dragging = false;
            }

            onCanceled: {
                slider.dragging = false;
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true

        Text {
            text: root.formatTime(slider.dragging ? slider.dragFraction * root.playback.durationSeconds : root.playback.positionSeconds)
            color: Colors.foregroundQuiet
            font.family: Constants.fontFamily
            font.pixelSize: 10
        }

        Item {
            Layout.fillWidth: true
        }

        Text {
            text: "-" + root.formatTime(Math.max(0, root.playback.durationSeconds - (slider.dragging ? slider.dragFraction * root.playback.durationSeconds : root.playback.positionSeconds)))
            color: Colors.foregroundQuiet
            font.family: Constants.fontFamily
            font.pixelSize: 10
        }
    }
}
