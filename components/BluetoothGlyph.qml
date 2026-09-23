import QtQuick
import qs.config

// The Bluetooth rune, in place of the `BT` label.
//
// **It is the standard mark, not one of ours.** Three hand-drawn versions
// came before this -- filled, then stroked at 2 px, then at 1 -- and each was
// wrong in a way the last was not: a slab, then chunky, then thin and still
// misshapen. The last of them measured 11 wide by 13 tall, and the real rune
// is close to half as wide as it is tall. A logo with fixed proportions is
// not something to redraw by eye at 13 px.
//
// `JetBrainsMono Nerd Font` is the data family's own patched build, so this
// glyph sits on the same metrics as the labels beside it, is hinted for the
// sizes the bar uses, and takes a colour like any other text. **U+F00AF, the
// Material Design rune** -- measured 9 x 15 at 15 px, a ratio of 0.60 --
// rather than U+F293, which is a filled blob at this size.
//
// It stays the label grey in every state: it stands in for a word, not for a
// reading. The device name beside it is what carries the data colour.
Item {
    id: root

    property color color: Theme.dim

    // The layout slot is unchanged, so nothing on the bar moves.
    implicitWidth: 13
    implicitHeight: 15

    Glyph {
        anchors.centerIn: parent
        // Above the BMP, so it needs the code point rather than an escape.
        text: String.fromCodePoint(0xF00AF)
        color: root.color
        family: Appearance.font.icons
        pixelSize: 15
    }
}
