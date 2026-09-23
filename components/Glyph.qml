import QtQuick
import qs.config

// A single glyph centred on **its ink**, not on its line box.
//
// `anchors.centerIn` centres a `Text` item, and a `Text` item is as tall as
// the font's whole line -- ascent, descent and all -- whatever the character
// actually draws. For letters that hardly matters; for a lone `✓` or `★` in a
// small square it is most of the box, and both sat visibly low and left of
// centre inside the pool chips' controls.
//
// The measurement is the same one the bar clock's seconds are aligned by:
// a glyph's ink top is `FontMetrics.ascent + TextMetrics.tightBoundingRect.y`,
// because the tight rect is measured from the baseline rather than from the
// item. Doing it this way means it stays right for any glyph at any size,
// rather than being nudged by an offset that is correct for one of them.
Item {
    id: root

    property string text: ""
    property color color: Theme.text
    property real pixelSize: 12
    property string family: Appearance.font.data
    property int weight: Appearance.font.weightRegular

    implicitWidth: metrics.tightBoundingRect.width
    implicitHeight: metrics.tightBoundingRect.height

    TextMetrics {
        id: metrics

        font.family: root.family
        font.pixelSize: root.pixelSize
        font.weight: root.weight
        text: root.text
    }

    FontMetrics {
        id: line

        font: metrics.font
    }

    Text {
        x: root.width / 2 - (metrics.tightBoundingRect.x + metrics.tightBoundingRect.width / 2)
        y: root.height / 2 - (line.ascent + metrics.tightBoundingRect.y + metrics.tightBoundingRect.height / 2)

        text: root.text
        color: root.color
        font: metrics.font
        renderType: Text.NativeRendering
    }
}
