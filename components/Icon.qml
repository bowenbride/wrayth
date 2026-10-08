import QtQuick
import qs.config

// An icon from Material Symbols Sharp (DESIGN.md section 5): rendered as text
// by its ligature, from the bundled variable font at FILL 1, weight 400,
// grade 0, optical size 20. Never an image, never scaled by a transform: the
// size is a whole number of pixels, and the glyph's ink is centred in its box
// and snapped to whole pixels (measured, not assumed: centring the text box
// left the ink half a pixel off, blurring its right and bottom edges).
//
// **An icon's name never appears as text.** The font is loaded by the shell
// itself (config/IconFont.qml); until it is ready, or if a name does not
// resolve to a glyph (a ligature sets one glyph about `size` wide, the letters
// of a name far wider), nothing is drawn in the reserved box and the shell logs
// one warning -- never the ligature's name.
Item {
    id: root

    // The icon's name, as Material Symbols names it: "inbox", "volume_up".
    property string name: ""
    property color color: Tokens.color.dim
    property int size: Tokens.icon.bar

    implicitWidth: size
    implicitHeight: size

    // The name set as one glyph in the loaded font.
    readonly property bool resolved: IconFont.ready && name !== "" && ink.advanceWidth > 0 && ink.advanceWidth <= size * 1.25
    onResolvedChanged: if (IconFont.ready && name !== "" && !resolved) IconFont.warn(`"${name}" is not an icon in it`)

    TextMetrics {
        id: ink
        font: glyph.font
        text: root.name
    }

    Text {
        id: glyph

        // Whole-pixel offsets that put the ink's box in the middle of ours.
        // Centred in whatever box the icon is given (its own size, or a
        // host's button it fills).
        x: Math.round((root.width - ink.tightBoundingRect.width) / 2 - ink.tightBoundingRect.x)
        y: Math.round((root.height - ink.tightBoundingRect.height) / 2 - ink.tightBoundingRect.y - fm.ascent)
        visible: root.resolved
        text: IconFont.ready ? root.name : ""
        color: root.color
        font.family: IconFont.family
        font.pixelSize: root.size
        font.variableAxes: ({ "FILL": 1, "wght": 400, "GRAD": 0, "opsz": 20 })
        font.hintingPreference: Font.PreferFullHinting
        renderType: Text.NativeRendering
    }
    FontMetrics {
        id: fm
        font: glyph.font
    }
}
