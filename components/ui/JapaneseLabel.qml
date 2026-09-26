import QtQuick
import qs.config

// JapaneseLabel (DESIGN.md, 6): 11 px Noto Sans CJK JP in `signal`, its ink
// centred vertically on the centre of `title`'s Latin cap height, to the
// whole pixel. Place it 8 px after the title (Title does this).
Text {
    id: root

    // The title Text it sits beside, in the same parent.
    property Text title: null
    readonly property var role: Tokens.type.japanese

    color: Tokens.color.signal
    font.family: role.family
    font.pixelSize: role.size
    font.weight: role.weight
    textFormat: Text.PlainText
    renderType: Text.NativeRendering

    FontMetrics {
        id: own
        font: root.font
    }
    FontMetrics {
        id: titleMetrics
        font: root.title ? root.title.font : root.font
    }
    // QML's FontMetrics has no cap height, so it is the ink of an "H" in the
    // title's font, measured from the baseline.
    TextMetrics {
        id: cap
        font: root.title ? root.title.font : root.font
        text: "H"
    }
    TextMetrics {
        id: ink
        font: root.font
        text: root.text
    }
    // The title's cap centre and our ink centre, both from each one's top.
    y: title ? Math.round(title.y + titleMetrics.ascent + cap.tightBoundingRect.y + cap.tightBoundingRect.height / 2 - (own.ascent + ink.tightBoundingRect.y + ink.tightBoundingRect.height / 2)) : 0
}
