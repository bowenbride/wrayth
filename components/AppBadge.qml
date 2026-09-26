import QtQuick
import qs.config

// An app's two-letter badge, as the launcher shows apps: a square with a
// hairline border and two letters in Chakra Petch Bold. Used wherever an app
// needs a mark and its own icon would bring its own colours (the tray, the
// window switcher, the overview). Square: it never sits in a chamfered corner.
Rectangle {
    id: root

    property string name: ""
    property bool selected: false
    property real size: 26
    property real pixelSize: 11

    readonly property string letters: {
        const clean = String(name).replace(/^.*\./, "").replace(/[^A-Za-z0-9]/g, "");
        return (clean || "??").slice(0, 2).toUpperCase();
    }

    width: size
    height: size
    color: selected ? Tokens.color.accent : Theme.cell
    border.width: Tokens.measure.hairline
    border.color: selected ? Tokens.color.accent : Tokens.color.hair

    Text {
        anchors.centerIn: parent
        text: root.letters
        color: root.selected ? Tokens.color.ground : Tokens.color.text
        font.family: Tokens.font.display
        font.pixelSize: root.pixelSize
        font.weight: Appearance.font.weightBold
        renderType: Text.NativeRendering
    }
}
