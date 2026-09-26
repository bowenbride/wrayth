import QtQuick
import qs.config

// Tag (DESIGN.md): 8 px, 0.10em, padding 1 x 3 px. Outline (MIC): 1 px
// `accent` border, `accent` text. Solid (LIVE): `accent` fill, `ground` text.
Rectangle {
    id: root

    property alias text: label.text
    property bool solid: false

    implicitWidth: label.implicitWidth + 2 * 3
    implicitHeight: label.implicitHeight + 2 * 1
    color: solid ? Tokens.color.accent : "transparent"
    border.width: solid ? 0 : Tokens.measure.hairline
    border.color: Tokens.color.accent

    Text {
        id: label

        readonly property var role: Tokens.type.tag
        anchors.centerIn: parent
        color: root.solid ? Tokens.color.ground : Tokens.color.accent
        font.family: role.family
        font.pixelSize: role.size
        font.weight: role.weight
        font.letterSpacing: role.size * role.tracking
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
    }
}
