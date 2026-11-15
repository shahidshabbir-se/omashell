pragma ComponentBehavior: Bound

import QtQuick
import "../../../../config"

Item {
    id: root

    property bool isPlaying: false
    property bool hovered: false

    anchors.fill: parent

                                                 
    Rectangle {
        id: vinylBody
        anchors.fill: parent
        radius: width / 2
        color: "#0f0e15"
        border.width: 1.5
        border.color: Colors.withAlpha(Colors.muted, 0.28)
    }

                      
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 6
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Colors.withAlpha(Colors.foreground, 0.08)
    }

                                                      
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

                                                                                   
    Item {
        anchors.fill: parent
        opacity: root.hovered ? 0.25 : 0.16

        Behavior on opacity {
            NumberAnimation {
                duration: 300
            }
        }

                                                                 
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

                                           
    Rectangle {
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.46)
        height: width
        radius: width / 2
        color: "transparent"
        border.width: 1
        border.color: Colors.withAlpha(Colors.foreground, 0.12)
    }

                                                                     
    Rectangle {
        id: centerLabel
        anchors.centerIn: parent
        width: Math.round(parent.width * 0.36)
        height: width
        radius: width / 2
        color: Colors.accent

        border.width: 2
        border.color: Colors.withAlpha(Colors.backgroundDeep, 0.5)

                                             
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

                                       
        Rectangle {
            anchors.centerIn: parent
            width: parent.width - 14
            height: width
            radius: width / 2
            color: "transparent"
            border.width: 1
            border.color: Colors.withAlpha(Colors.background, 0.35)
        }

                                                                     
        Text {
            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            text: "󰎆"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Math.round(centerLabel.width * 0.30)
            color: Colors.background
            opacity: 0.88
        }

                                                                                
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
