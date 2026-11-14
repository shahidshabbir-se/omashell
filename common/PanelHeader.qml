import QtQuick
import qs.config

// Title + caption for the top of a panel, with room for a trailing control (a
// toggle, a counter). Text centred on the two-line block, not on the title line.
Item {
  id: root

  property string title: ""
  property string caption: ""
  property bool hasCursor: false

  default property alias trailing: trailingRow.children

  implicitHeight: Math.max(titleColumn.implicitHeight, trailingRow.implicitHeight)

  Column {
    id: titleColumn

    anchors.left: parent.left
    anchors.verticalCenter: parent.verticalCenter
    spacing: 1

    OpticalText {
      text: root.title
      pixelSize: Constants.fontTitle
      color: Colors.brightForeground
    }

    OpticalText {
      visible: root.caption !== ""
      text: root.caption.toUpperCase()
      pixelSize: Constants.fontCaption
      color: Colors.darkForeground
    }
  }

  Row {
    id: trailingRow

    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    spacing: Constants.gap
  }
}
