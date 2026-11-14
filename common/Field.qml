import QtQuick
import qs.config

// Single-line text entry in the panel's own look: a sunk field, our tokens, no
// platform style. Editing is explicit - the panel's keyboard navigation focuses
// it on activate(), Escape or Return hands control back.
Item {
  id: root

  property string text: ""
  property string placeholder: ""
  property bool password: false
  property bool navigable: true
  property bool hasCursor: false

  signal submitted(string text)
  signal editingFinished()

  readonly property bool editing: input.activeFocus

  implicitHeight: 28

  function activate() {
    input.forceActiveFocus()
  }

  function clear() {
    root.text = ""
    input.text = ""
  }

  Rectangle {
    anchors.fill: parent
    radius: Constants.cornerRadius
    color: Colors.darkerBackground
    border.width: root.hasCursor || root.editing ? 1 : 0
    border.color: root.editing ? Colors.accent : Colors.muted

    Text {
      anchors.fill: parent
      anchors.leftMargin: 8
      anchors.rightMargin: 8
      visible: input.text.length === 0
      text: root.placeholder
      color: Colors.muted
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontBody
      textFormat: Text.PlainText
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideRight
    }

    TextInput {
      id: input

      anchors.fill: parent
      anchors.leftMargin: 8
      anchors.rightMargin: 8
      verticalAlignment: TextInput.AlignVCenter
      color: Colors.foreground
      selectionColor: Colors.accent
      selectedTextColor: Colors.background
      font.family: Constants.fontFamily
      font.pixelSize: Constants.fontBody
      echoMode: root.password ? TextInput.Password : TextInput.Normal
      text: root.text

      onTextEdited: root.text = text

      Keys.onReturnPressed: {
        root.submitted(root.text)
        root.editingFinished()
      }

      Keys.onEscapePressed: {
        root.editingFinished()
      }
    }
  }

  MouseArea {
    anchors.fill: parent
    cursorShape: Qt.IBeamCursor
    onClicked: root.activate()
  }
}
