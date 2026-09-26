import QtQuick
import qs.config

// A key in a box, for anything that advertises a keyboard shortcut. The bare
// glyphs did not survive the label size -- `⏎` at 11 px is a few grey pixels --
// so a key is named and framed instead.
//
// Border and text are one colour, taken from whatever line the cap sits in, so
// a cap inside an accent status line turns accent with it and one in a `mute`
// footer stays mute. Nothing here colours itself.
Item {
    id: root

    // ENTER, ESC, or an arrow pair such as ↑↓ -- a direction has no short name
    // and its glyph is legible where the return symbol is not.
    // DESIGN.md Keycap: 18 px tall, 6 px sides, a 1 px `hair` border,
    // rgba(0,0,0,0.35) fill, the key at 9 px in `bright`; a changed bind in
    // `accent`. `color` is kept for callers and no longer changes the cap.
    property string key: ""
    property color color: Tokens.color.dim
    property bool changed: false
    property real pixelSize: Tokens.type.keycap.size
    property real hPadding: Tokens.measure.keycapPadding

    implicitWidth: label.implicitWidth + hPadding * 2
    implicitHeight: Tokens.measure.keycap

    Rectangle {
        anchors.fill: parent

        color: Tokens.color.keycapFill
        border.width: Tokens.measure.hairline
        border.color: root.changed ? Tokens.color.accent : Tokens.color.hair
    }

    // **The cap's own label, ink-centred.** It used to carry a hand-written
    // `-letterSpacing / 2` offset, which was the right size and the wrong
    // sign: letter-spacing is added *after* the last glyph, so the ink sits
    // half a space to the **left** of the advance box's centre and shifting it
    // further left doubled the error. Measured in the picker's key hints
    // before this changed: `ENTER` 1.5 px left of its cap's centre, `ESC`
    // 1.0 px, the arrow pair 2.0 px. `NrLabel` measures both axes instead.
    NrLabel {
        id: label

        anchors.centerIn: parent
        centred: true

        text: root.key
        color: root.changed ? Tokens.color.accent : Tokens.color.bright
        pixelSize: root.pixelSize
        font.letterSpacing: 0
    }
}
