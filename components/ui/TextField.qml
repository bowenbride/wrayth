import QtQuick
import qs.config

// TextField (DESIGN.md): free text. 28 px, 1 px `hair` border (`accent` when
// focused), text 11 px, placeholder `dim`, a visible caret. Takes typing the
// moment it appears.
Rectangle {
    id: root

    property alias text: input.text
    property string placeholder: ""
    property alias validator: input.validator
    signal accepted
    signal escaped

    readonly property var role: Tokens.type.body

    implicitHeight: Tokens.measure.field
    color: "transparent"
    border.width: Tokens.measure.hairline
    border.color: input.activeFocus ? Tokens.color.accent : Tokens.color.hair

    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: Tokens.space.s8
        anchors.rightMargin: Tokens.space.s8
        verticalAlignment: TextInput.AlignVCenter
        clip: true
        color: Tokens.color.text
        selectionColor: Tokens.color.accentFill
        font.family: root.role.family
        font.pixelSize: root.role.size
        renderType: Text.NativeRendering
        cursorDelegate: Rectangle {
            width: Tokens.measure.hairline
            color: Tokens.color.accent
            visible: input.activeFocus
        }
        Component.onCompleted: forceActiveFocus()
        onAccepted: root.accepted()
        Keys.onEscapePressed: root.escaped()

        Text {
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            visible: input.text === ""
            text: root.placeholder
            color: Tokens.color.dim
            font: input.font
            renderType: Text.NativeRendering
        }
    }
}
