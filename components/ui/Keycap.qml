import QtQuick
import qs.config

// Keycap (DESIGN.md): 18 px tall, 6 px sides, 1 px `hair` border,
// rgba(0,0,0,0.35) fill, 9 px `bright`. Changed binds: `accent` border and label.
Rectangle {
    id: root

    property alias text: label.text
    property bool changed: false

    implicitWidth: label.implicitWidth + 2 * Tokens.measure.keycapPadding
    implicitHeight: Tokens.measure.keycap
    color: Tokens.color.keycapFill
    border.width: Tokens.measure.hairline
    border.color: changed ? Tokens.color.accent : Tokens.color.hair

    Text {
        id: label

        readonly property var role: Tokens.type.keycap
        anchors.centerIn: parent
        color: root.changed ? Tokens.color.accent : Tokens.color.bright
        font.family: role.family
        font.pixelSize: role.size
        font.weight: role.weight
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
    }
}
