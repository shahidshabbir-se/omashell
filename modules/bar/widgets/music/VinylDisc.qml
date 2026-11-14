pragma ComponentBehavior: Bound

import QtQuick
import "../../../../config"

Item {
    id: root

    property bool isPlaying: false
    property bool hovered: false

    anchors.fill: parent

    // Base vinyl body: deep sleek record surface
    Rectangle {
        id: vinylBody
        anchors.fill: parent
        radius: width / 2
        color: "#0f0e15"
        border.width: 1.5
        border.color: Colors.withAlpha(Colors.muted, 0.28)
    }

    // Outer rim bevel
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 6
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Colors.withAlpha(Colors.foreground, 0.08)
    }

    // Concentric sound grooves with varying opacities
    Repeater {
        model: [14, 24, 34, 46, 56, 68, 78, 90, 100, 112]

        Rectangle {
            required property int modelData
            required property int index

            anchors.centerIn: parent
            width: parent.width - modelData * 2
            height: width
            radius: width / 2
            color: "transparent"
            border.width: (index % 3 === 0) ? 1.5 : 1
            border.color: Colors.withAlpha(Colors.foreground, (index % 2 === 0) ? 0.06 : 0.035)
        }
    }

    // Vinyl light reflection sheens (the cross-light sheen seen on physical vinyl)
    Item {
        anchors.fill: parent
        opacity: root.hovered ? 0.25 : 0.16

        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }

        // Reflection 1: Top-left to bottom-right sheen highlight
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.94
            height: width
            radius: width / 2
            color: "transparent"
            rotation: 35

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.42
                    color: "transparent"
                }
                GradientStop {
                    position: 0.50
                    color: Colors.withAlpha(Colors.accent, 0.32)
                }
                GradientStop {
                    position: 0.58
                    color: "transparent"
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
        }

        // Reflection 2: Opposing sheen highlight
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.94
            height: width
            radius: width / 2
            color: "transparent"
            rotation: -35

            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop {
                    position: 0.0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.42
                    color: "transparent"
                }
                GradientStop {
                    position: 0.50
                    color: Colors.withAlpha(Colors.accent, 0.25)
                }
                GradientStop {
                    position: 0.58
                    color: "transparent"
                }
                GradientStop {
                    position: 1.0
                    color: "transparent"
                }
            }
        }
    }

    // Run-out groove (dead wax inner ring)
    Rectangle {
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.46)
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Colors.withAlpha(Colors.foreground, 0.12)
    }

    // Center record label — glowing with the theme's primary accent!
    Rectangle {
        id: centerLabel
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.36)
        height: width
        radius: width / 2
        color: Colors.accent

        border.width: 2
        border.color: Colors.withAlpha(Colors.backgroundDeep, 0.5)

        // Subtle gradient sheen on the label
        Rectangle {
            anchors.fill: parent
            radius: parent.radius
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop {
                    position: 0.0
                    color: Colors.withAlpha(Colors.foreground, 0.20)
                }
                GradientStop {
                    position: 0.5
                    color: "transparent"
                }
                GradientStop {
                    position: 1.0
                    color: Colors.withAlpha(Colors.backgroundDeep, 0.25)
                }
            }
        }

        // Inner circular band on label
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 14
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Colors.withAlpha(Colors.background, 0.35)
        }

        // Musical note glyph / vinyl record icon in the center label
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            text: "󰎆"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Math.round(centerLabel.width * 0.30)
            color: Colors.background
            opacity: 0.88
        }

        // Center spindle hole (shows through to background with a metallic rim)
        Rectangle {
            anchors.centerIn: parent
            width: 14
            height: 14
            radius: 7
            color: Colors.background
            border.width: 1.5
            border.color: Colors.withAlpha(Colors.background, 0.5)
        }
    }
}
