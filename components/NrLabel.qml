import QtQuick
import qs.config

// A small uppercase tracked label: 10px, 0.14em, dim by default.
// Override `pixelSize` rather than `font.pixelSize` so the tracking follows.
Text {
    id: root

    property real pixelSize: Appearance.size.label
    property bool tracked: true

    // **Set this on any label that is centred in something.** A `Text` item is
    // not its ink, in either direction, and centring the item leaves the ink
    // off centre both ways:
    //
    //   horizontally -- a tracked label carries its letter-spacing after its
    //     final glyph as well as between the others, so the advance box is
    //     half a space wider on the right than the ink is.
    //   vertically -- the item is as tall as the font's whole line, ascent and
    //     descent together, and an uppercase label draws in the top half of
    //     that. Measured on the pools screen's `CARD` tag before this existed:
    //     the ink sat a full pixel high in a 14 px tag.
    //
    // The correction is a **transform**, not padding: it moves the painted ink
    // and leaves the item's own size and position exactly as they were, so a
    // host that measures `implicitWidth` gets the same number it always did
    // and nothing anywhere re-lays out.
    property bool centred: false

    // Where the ink's centre actually is, against the item's own centre. Both
    // are measured rather than nudged by a constant, so they stay right for
    // any string at any size -- the same rule `Glyph` follows.
    readonly property real inkOffsetX: centred && tracked ? font.letterSpacing / 2 : 0
    // **Vertically the correction has to be a whole pixel, horizontally it does
    // not.** `Text.NativeRendering` positions glyphs with sub-pixel precision
    // along the line and snaps the baseline to the pixel grid across it -- so
    // a 0.41 px vertical nudge is rounded away and changes nothing, while the
    // same nudge sideways lands. Measured on the `CARD` tag: the metrics put
    // the ink 0.41 px high, the raster put it a full pixel high, and only the
    // rounded correction moved it.
    readonly property real inkOffsetY: {
        if (!centred || !ink.text || height <= 0)
            return 0;
        // Where the baseline actually lands, snapped the way the rasteriser
        // snaps it, rather than where the layout maths says it is.
        const baseline = Math.round(Math.floor((height - line.height) / 2) + line.ascent);
        const inkCentre = baseline + ink.tightBoundingRect.y + ink.tightBoundingRect.height / 2;
        return Math.round(height / 2 - inkCentre);
    }

    transform: Translate {
        x: root.inkOffsetX
        y: root.inkOffsetY
    }

    TextMetrics {
        id: ink

        font: root.font
        text: root.text
    }

    FontMetrics {
        id: line

        font: root.font
    }

    color: Theme.dim
    font.family: Appearance.font.data
    font.pixelSize: pixelSize
    font.weight: Appearance.font.weightSemi
    font.letterSpacing: tracked ? Appearance.tracking(pixelSize) : 0
    font.capitalization: Font.AllUppercase
    renderType: Text.NativeRendering
    verticalAlignment: Text.AlignVCenter
    // **Plain text, always.** A bare `Text` defaults to `Text.AutoText`, which
    // runs `Qt.mightBeRichText()` on the string and switches to HTML if it
    // looks like markup -- so an SSID, a Bluetooth device name, an app name or
    // a planner tag containing `<a href=...>` or `<img src=...>` would render
    // as rich text. NrLabel carries untrusted strings all over the shell, so it
    // never interprets markup.
    textFormat: Text.PlainText
}
