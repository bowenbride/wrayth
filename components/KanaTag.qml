import QtQuick
import qs.config

// The Japanese tag beside a title (`無線`, `音量`, `システム診断` ...), at its
// usual size and colour, **vertically centred on the title's ink**.
//
// Both sit in their row by `anchors.verticalCenter`, which centres their line
// boxes -- and a line box is not the ink. The CJK face draws its glyphs low in
// a tall box, while the titles are capitals sitting high in theirs, so a tag
// centred by box hung below the title. This measures both inks the way
// `Glyph` does (a glyph's ink centre is `ascent + tightBoundingRect.y +
// tightBoundingRect.height / 2` from the top of its box) and moves the tag's
// text by the difference, so the two ink centres coincide. The item keeps the
// tag's own box, so nothing around it moves.
//
// `title` is the Text (or NrLabel) the tag sits beside, on the same line.
Item {
    id: root

    property string text: ""
    property Item title: null
    property color color: Theme.signal
    property real pixelSize: Appearance.size.katakana
    // With no title: centre the tag's own ink on its line (the bar's ticker
    // tag), instead of leaving it where its box puts it (a tag on a line of
    // its own under a heading).
    property bool centreInk: false

    implicitWidth: kana.implicitWidth
    implicitHeight: kana.implicitHeight

    TextMetrics {
        id: kanaInk

        font: kana.font
        text: root.text
    }
    FontMetrics {
        id: kanaLine

        font: kana.font
    }
    TextMetrics {
        id: titleInk

        font: root.title?.font ?? kana.font
        text: root.title?.text ?? ""
    }
    FontMetrics {
        id: titleLine

        font: titleInk.font
    }

    // Each ink centre, measured from the centre of its own line box.
    readonly property real kanaCentre: kanaLine.ascent + kanaInk.tightBoundingRect.y + kanaInk.tightBoundingRect.height / 2 - kana.implicitHeight / 2
    readonly property real titleCentre: root.title && root.title.text !== ""
        ? titleLine.ascent + titleInk.tightBoundingRect.y + titleInk.tightBoundingRect.height / 2 - root.title.height / 2
        : (root.centreInk ? 0 : kanaCentre)

    Text {
        id: kana

        y: Math.round(root.titleCentre - root.kanaCentre)
        text: root.text
        color: root.color
        font.family: Appearance.font.accent
        font.pixelSize: root.pixelSize
        font.weight: Appearance.font.weightMedium
        renderType: Text.NativeRendering
    }
}
