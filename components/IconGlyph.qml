import QtQuick
import qs.config

// A Material Design mark from the data family's Nerd Font build, centred on
// its ink (see Glyph) in a fixed slot, so a readout that swaps one icon for
// another never moves. `code` is the code point (they sit above the BMP).
Item {
    id: root

    property int code: 0
    property color color: Tokens.color.dim
    property real pixelSize: 15
    property real slot: 15

    implicitWidth: slot
    implicitHeight: slot

    Glyph {
        anchors.centerIn: parent
        text: root.code > 0 ? String.fromCodePoint(root.code) : ""
        color: root.color
        family: Appearance.font.icons
        pixelSize: root.pixelSize

        Behavior on color {
            ColorAnimation {
                duration: Tokens.motion.feedback
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeIn
            }
        }
    }
}
