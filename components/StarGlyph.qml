import QtQuick
import QtQuick.Shapes
import qs.config

// The star that marks a wallpaper as a profile's card image, **drawn rather
// than typed** -- for the same reason the cross beside it is.
//
// Centring a glyph on its measured ink gets a tick to within half a pixel,
// but not a star: `★` is not in JetBrains Mono, so it arrives from whatever
// font Qt substitutes, with that font's bearings and its own idea of where
// the baseline sits. Measured, it landed a pixel low in an 18 px button and
// it showed. A polygon has no bearings.
Item {
    id: root

    property color color: Theme.text
    // How far the points stop short of the button's edge.
    property real inset: 2

    readonly property real outer: Math.max(0, Math.min(width, height) / 2 - inset)

    // **Fatter than a regular pentagram, deliberately.** The textbook inner
    // radius is 0.382 of the outer, which gives needle points; at this size
    // those antialias away to nothing and the legs vanish, leaving a
    // top-heavy blob that reads as sitting high however exactly it is
    // centred. 0.46 keeps the silhouette and gives every point enough width
    // to render.
    readonly property real inner: outer * 0.46

    // **Centred on the circumcircle, not on the bounding box.** The box is
    // asymmetric -- the top point reaches the full radius while the two legs
    // only reach `r * cos 36` -- so it is tempting to push the star down by
    // half that difference. That was tried and measured, and it is wrong: the
    // intensity-weighted centroid of the drawn star sits within **0.08 px**
    // of the circle's centre, and the correction moved it **0.67 px off**.
    // The bounding box ends up half a pixel high and the mark itself does
    // not, which is the direction type is optically centred in anyway.
    readonly property real midX: width / 2
    readonly property real midY: height / 2

    readonly property string outline: {
        const parts = [];
        for (let i = 0; i < 10; i++) {
            // From the top, 36 degrees at a time, alternating radii.
            const angle = -Math.PI / 2 + i * Math.PI / 5;
            const r = i % 2 === 0 ? root.outer : root.inner;
            const x = root.midX + r * Math.cos(angle);
            const y = root.midY + r * Math.sin(angle);
            parts.push(`${i === 0 ? "M" : "L"} ${x.toFixed(3)} ${y.toFixed(3)}`);
        }
        parts.push("Z");
        return parts.join(" ");
    }

    Shape {
        anchors.fill: parent
        // The standing rule: a Shape whose fill is bound to state takes the
        // geometry renderer.
        preferredRendererType: Shape.GeometryRenderer

        ShapePath {
            fillColor: root.color
            strokeWidth: 0
            strokeColor: "transparent"

            PathSvg {
                path: root.outline
            }
        }
    }
}
