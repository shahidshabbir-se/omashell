import QtQuick
import qs.common
import qs.config

Widget {
  id: root

  readonly property real barSlotWidth: Constants.iconSlot
  implicitWidth: 21
  implicitHeight: 21

  Image {
    anchors.centerIn: parent
    width: Constants.iconSize * 1.2
    height: width
    source: Qt.resolvedUrl('../../../../assets/omashell-monogram.svg')
    sourceSize.width: 96
    sourceSize.height: 96
    fillMode: Image.PreserveAspectFit
    smooth: true
  }
}
