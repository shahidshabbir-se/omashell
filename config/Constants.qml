pragma Singleton
import QtQuick

QtObject {
  readonly property int cornerRadius: 0
  readonly property int barHeight: 28
  readonly property int gap: 5
  readonly property int panelPadding: 14
                                                                                   
  readonly property int deviceRowPaddingY: 12

  readonly property string fontFamily: "JetBrainsMono Nerd Font"
  readonly property int fontCaption: 10
  readonly property int fontBodySmall: 11
  readonly property int fontBody: 12
  readonly property int fontSubtitle: 13
  readonly property int fontTitle: 14
  readonly property int fontHeading: 16
  readonly property int fontDisplay: 24

                                                                               
                                                                             
                                                     
  readonly property int iconSize: 12

                                                                      
  readonly property int indicatorThickness: 2
  readonly property int indicatorInset: 2
  readonly property int indicatorMinimumWidth: 10

                                              
  readonly property int tooltipDelay: 400

                                                                             
                                                                              
                                                               
  readonly property real barWidgetPadding: 8.5
                                                                                 
                                                                                     
  readonly property int iconSlot: 27
  readonly property int statusSlot: 21
                                                       
  readonly property int barSectionMargin: 8
  readonly property int widgetDragThreshold: 4
  readonly property int widgetRemoveDistance: 48
  readonly property int barMoveHoldDuration: 200

  readonly property int cellWidth: 52
  readonly property int cellHeight: 34
  readonly property int cellSpacing: 2
  readonly property int weekColumnWidth: 32
  readonly property int gutterWidth: 14

                              
  readonly property int visualizerBarCount: 72
  readonly property int visualizerInputRange: 7
  readonly property real visualizerInputGain: 2.2
  readonly property real visualizerCenterWeight: 0.6
  readonly property real visualizerNeighborWeight: 0.2
  readonly property real visualizerLevelCurve: 0.6
  readonly property real visualizerActivityThreshold: 0.01
  readonly property int visualizerSilenceTimeout: 500
  readonly property int visualizerBarWidth: 5
  readonly property int visualizerBarSpacing: 4
  readonly property int visualizerMaxBarHeight: 54
  readonly property int visualizerMinBarHeight: 2
  readonly property int visualizerBarRadius: 1
  readonly property int visualizerHeight: 72
  readonly property int visualizerBottomMargin: 1
  readonly property int visualizerAnimationDuration: 300
}
