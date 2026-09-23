import QtQuick
import QtQuick.Shapes
import qs.config

// The cross in a close or remove button, **drawn rather than typed**.
//
// A `×` from the font is a small mark floating in the middle of its own
// bearings: at the size these buttons are it read as a speck and could not be
// told from the tick beside it. Two bars across the whole box are legible at
// any size and take the button's colour without a font in the way.
//
// **Stroked lines, not rotated rectangles.** The first version rotated two
// `Rectangle`s 45 degrees about their centres, which is exact geometry and
// still rasterised half a pixel to the right -- measured, margins of 2 px on
// the left against 1 px on the right. A stroke laid on the path itself lands
// symmetrically.
Item {
    id: root

    property color color: Theme.text
    property real thickness: 2
    // How far the ends of the cross stop short of the button's edge.
    property real inset: 3

    readonly property real near: inset
    readonly property real far: Math.max(inset, Math.min(width, height) - inset)

    Shape {
        anchors.fill: parent
        // The standing rule: a Shape whose stroke is bound to state takes the
        // geometry renderer.
        preferredRendererType: Shape.GeometryRenderer

        ShapePath {
            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.thickness
            capStyle: ShapePath.FlatCap

            PathSvg {
                path: `M ${root.near} ${root.near} L ${root.far} ${root.far} M ${root.far} ${root.near} L ${root.near} ${root.far}`
            }
        }
    }
}
