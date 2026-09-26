import QtQuick
import QtQuick.Shapes
import qs.config

// The Bluetooth rune (DESIGN.md, a bespoke icon): stroke-drawn, 1.7 px, no
// fill, mitred joins, in a 10 x 16 box. `dim` idle; the bar's value `text`
// colour while a device is connected (the readout sets `color`).
Item {
    id: root

    property color color: Tokens.color.dim

    implicitWidth: 10
    implicitHeight: 16

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.GeometryRenderer

        ShapePath {
            strokeWidth: 1.7
            strokeColor: root.color
            fillColor: "transparent"
            joinStyle: ShapePath.MiterJoin
            capStyle: ShapePath.FlatCap

            // The lower-left arm, across to the lower chevron, up the spine,
            // round the upper chevron, down to the upper-left arm.
            startX: 1
            startY: 4.5
            PathLine { x: 8.8; y: 11.2 }
            PathLine { x: 5; y: 15 }
            PathLine { x: 5; y: 1 }
            PathLine { x: 8.8; y: 4.8 }
            PathLine { x: 1; y: 11.5 }
        }
    }
}
