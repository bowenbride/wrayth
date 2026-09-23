import QtQuick
import qs.config

// The deck's accent brackets: 12x12, 2px thick L-shapes. They only ever sit on
// a *square* corner, so which pair is drawn follows the panel's cut scheme --
// the HUD cuts top-right and bottom-left and brackets the other two, the signal
// panel is its mirror.
Item {
    id: root

    property color color: Theme.accent
    property real size: 12
    property real thickness: 2
    property real inset: 0
    // Any of "topLeft", "topRight", "bottomRight", "bottomLeft".
    property var corners: ["topLeft", "bottomRight"]

    anchors.fill: parent

    Repeater {
        model: root.corners

        Item {
            required property string modelData

            readonly property bool atTop: modelData === "topLeft" || modelData === "topRight"
            readonly property bool atLeft: modelData === "topLeft" || modelData === "bottomLeft"

            x: atLeft ? root.inset : root.width - root.size - root.inset
            y: atTop ? root.inset : root.height - root.size - root.inset
            width: root.size
            height: root.size

            // The arm along the top or bottom edge.
            Rectangle {
                width: parent.width
                height: root.thickness
                y: parent.atTop ? 0 : parent.height - root.thickness
                color: root.color
            }

            // The arm down the left or right edge.
            Rectangle {
                width: root.thickness
                height: parent.height
                x: parent.atLeft ? 0 : parent.width - root.thickness
                color: root.color
            }
        }
    }
}
