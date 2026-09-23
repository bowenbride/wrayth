import QtQuick
import qs.components
import qs.config

// The inline editor for one gig: its name, and its category. Used both when an
// existing row is being renamed and when a new gig is being added. The category
// is free text -- every user's are different -- uppercased as it is typed and
// capped at eight characters. Enter in either field saves; Escape cancels.
Item {
    id: root

    property string initialName: ""
    property string initialTag: ""
    property bool focusOnShow: false

    signal committed(string name, string tag)
    signal cancelled

    implicitHeight: 28

    function commit(): void {
        root.committed(nameField.text, tagField.text);
    }

    function focusName(): void {
        nameField.take();
    }

    Component.onCompleted: if (focusOnShow) Qt.callLater(root.focusName)

    ActionButton {
        id: saveButton

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "SAVE"
        accented: true
        onClicked: root.commit()
    }

    InputField {
        id: tagField

        anchors.right: saveButton.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 76
        text: root.initialTag
        placeholder: "TAG"
        maximumLength: 8

        // Uppercased in place; the service caps and uppercases again on save.
        onEdited: value => tagField.text = value.toUpperCase()
        onAccepted: root.commit()
        onEscaped: root.cancelled()
    }

    InputField {
        id: nameField

        anchors.left: parent.left
        anchors.right: tagField.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.initialName
        placeholder: "GIG NAME"

        onAccepted: root.commit()
        onEscaped: root.cancelled()
    }
}
