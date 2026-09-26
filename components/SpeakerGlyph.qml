import QtQuick
import QtQuick.Shapes
import qs.config

// A speaker with one sound wave, drawn in a 14 x 13 box: the bar's AUDIO
// readout. Drawn, never a font character.
Item {
    id: root

    property color color: Theme.dim

    implicitWidth: 14
    implicitHeight: 13

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.GeometryRenderer

        // The body and the cone.
        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.color

            startX: 0
            startY: 4
            PathLine { x: 3; y: 4 }
            PathLine { x: 7; y: 0.5 }
            PathLine { x: 7; y: 12.5 }
            PathLine { x: 3; y: 9 }
            PathLine { x: 0; y: 9 }
            PathLine { x: 0; y: 4 }
        }

        // The wave.
        ShapePath {
            strokeWidth: 1.4
            strokeColor: root.color
            fillColor: "transparent"
            capStyle: ShapePath.FlatCap

            startX: 9.6
            startY: 3.2
            PathQuad {
                x: 9.6
                y: 9.8
                controlX: 13.6
                controlY: 6.5
            }
        }
    }
}
