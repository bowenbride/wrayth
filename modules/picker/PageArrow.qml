import QtQuick
import qs.components
import qs.config

// A page arrow: a slim button the full height of the grid rather than a glyph
// in a box, so the pair reads as the grid's two edges.
//
// **Availability is carried by frame, fill and glyph together.** One of the
// three on its own is a decoration; all three moving at once is a state, and
// the arrow that cannot be used is the one the eye must not be drawn to.
Item {
    id: root

    // The two arrows cut opposite corners -- bottom-left on the left, top-right
    // on the right -- so they mirror the design system's chamfer pair across
    // the grid rather than repeating it on both sides.
    required property bool leading
    required property bool available

    signal activated

    implicitWidth: 26
    implicitHeight: 444

    ChamferPanel {
        anchors.fill: parent

        chamfer: 8
        chamferTopRight: root.leading ? 0 : 8
        chamferBottomLeft: root.leading ? 8 : 0
        fillColor: root.available ? Theme.alpha(Theme.accent, hover.hovered ? 0.18 : 0.08) : "transparent"
        borderColor: root.available ? Theme.accent : Theme.hair

        Behavior on fillColor {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }
    }

    Text {
        anchors.centerIn: parent

        text: root.leading ? "<" : ">"
        color: root.available ? Theme.accent : Theme.dim
        font.family: Appearance.font.display
        font.pixelSize: 16
        font.weight: Appearance.font.weightBold
        renderType: Text.NativeRendering

        Behavior on color {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }
    }

    HoverHandler {
        id: hover

        enabled: root.available
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: root.available
        onTapped: root.activated()
    }
}
