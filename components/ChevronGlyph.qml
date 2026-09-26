import QtQuick
import QtQuick.Shapes
import qs.config

// A chevron, drawn: `left` or `right`, stroked in the button's colour, in an
// 8 x 8 box by default. The optical centre of a chevron is behind its tip, so
// the stroke is drawn half a stroke towards the open side.
Item {
    id: root

    property string direction: "right"
    property color color: Theme.text
    property real thickness: 1.4

    implicitWidth: 8
    implicitHeight: 8

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.GeometryRenderer

        ShapePath {
            id: path

            readonly property real inX: root.direction === "left" ? root.width * 0.72 : root.width * 0.28
            readonly property real tipX: root.direction === "left" ? root.width * 0.28 : root.width * 0.72

            fillColor: "transparent"
            strokeColor: root.color
            strokeWidth: root.thickness
            capStyle: ShapePath.FlatCap
            joinStyle: ShapePath.MiterJoin

            startX: path.inX
            startY: 0.5
            PathLine {
                x: path.tipX
                y: root.height / 2
            }
            PathLine {
                x: path.inX
                y: root.height - 0.5
            }
        }
    }
}
