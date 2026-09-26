import QtQuick
import QtQuick.Shapes
import qs.config

// A media transport glyph, drawn in a 12 x 10 box: "previous" (a 2 px bar on
// the left and a triangle pointing left), "next" (its mirror), "play" (a
// triangle pointing right) and "pause" (two 3 px bars). Drawn, never a font
// character, so it is the same shape at every size and in every profile.
Item {
    id: root

    property string kind: "play"
    property color color: Theme.text

    implicitWidth: 12
    implicitHeight: 10

    // previous / next: the bar.
    Rectangle {
        visible: root.kind === "previous" || root.kind === "next"
        x: root.kind === "previous" ? 0 : root.width - 2
        width: 2
        height: root.height
        color: root.color
    }

    // pause: two bars.
    Rectangle {
        visible: root.kind === "pause"
        x: 2
        width: 3
        height: root.height
        color: root.color
    }
    Rectangle {
        visible: root.kind === "pause"
        x: root.width - 5
        width: 3
        height: root.height
        color: root.color
    }

    // The triangles: pointing left (previous), right (next, play).
    Shape {
        anchors.fill: parent
        visible: root.kind !== "pause"
        preferredRendererType: Shape.GeometryRenderer

        ShapePath {
            id: tri

            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.color

            // previous: tip at x = 3, base at the right edge
            // next:     base at x = 0, tip at width - 3
            // play:     base at x = 2, tip at width - 1
            readonly property real baseX: root.kind === "previous" ? root.width : root.kind === "next" ? 0 : 2
            readonly property real tipX: root.kind === "previous" ? 3 : root.kind === "next" ? root.width - 3 : root.width - 1

            startX: baseX
            startY: 0
            PathLine {
                x: tri.tipX
                y: root.height / 2
            }
            PathLine {
                x: tri.baseX
                y: root.height
            }
            PathLine {
                x: tri.baseX
                y: 0
            }
        }
    }
}
