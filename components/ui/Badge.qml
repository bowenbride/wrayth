import QtQuick
import qs.config

// Badge (DESIGN.md): two letters in Chakra Petch in a square with a 1 px
// `hair` border; 26 px (22 px in tiles, letters 10 px). Replaces third-party
// app icons everywhere. Selected: `accent` border and letters.
Rectangle {
    id: root

    property string name: ""
    property bool small: false
    property bool selected: false
    readonly property string letters: {
        const clean = String(name).replace(/^.*\./, "").replace(/[^A-Za-z0-9]/g, "");
        return (clean || "??").slice(0, 2).toUpperCase();
    }

    width: small ? Tokens.measure.badgeSmall : Tokens.measure.badge
    height: width
    color: "transparent"
    border.width: Tokens.measure.hairline
    border.color: selected ? Tokens.color.accent : Tokens.color.hair

    Text {
        readonly property var role: root.small ? Tokens.type.badgeSmall : Tokens.type.badge
        anchors.centerIn: parent
        text: root.letters
        color: root.selected ? Tokens.color.accent : Tokens.color.text
        font.family: role.family
        font.pixelSize: role.size
        font.weight: role.weight
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
    }
}
