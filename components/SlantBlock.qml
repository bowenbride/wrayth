import QtQuick
import QtQuick.Shapes
import qs.config

// A filled block whose right edge is slanted, as on the NR//01 logo, the
// terminal's active tab and the notification level tab.
Item {
    id: root

    property color fillColor: Theme.accent
    property real slant: 14
    default property alias content: holder.data

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            fillColor: root.fillColor
            strokeWidth: 0
            strokeColor: "transparent"

            startX: 0
            startY: 0
            PathLine {
                x: root.width
                y: 0
            }
            PathLine {
                x: root.width - root.slant
                y: root.height
            }
            PathLine {
                x: 0
                y: root.height
            }
            PathLine {
                x: 0
                y: 0
            }
        }
    }

    Item {
        id: holder

        anchors.fill: parent
    }
}
