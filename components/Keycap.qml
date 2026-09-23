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
    property string key: ""
    property color color: Theme.dim
    property real pixelSize: Appearance.size.label
    property real hPadding: 5
    property real vPadding: 2

    implicitWidth: label.implicitWidth + hPadding * 2
    implicitHeight: label.implicitHeight + vPadding * 2

    Rectangle {
        anchors.fill: parent

        color: "transparent"
        border.width: Appearance.metrics.hairline
        border.color: root.color
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
        color: root.color
        pixelSize: root.pixelSize
    }
}
