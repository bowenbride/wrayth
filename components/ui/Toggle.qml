import QtQuick
import qs.components as C
import qs.config

// Toggle (DESIGN.md): 58 x 22 px, ON or OFF (or the state's name). On:
// `accent` border, 12% tint, `accent` label. Off: `hair` border, `dim` label.
Rectangle {
    id: root

    property bool on: false
    property string onText: "ON"
    property string offText: "OFF"
    signal toggled

    implicitWidth: Tokens.measure.toggleWidth
    implicitHeight: Tokens.measure.toggleHeight
    color: on ? Tokens.color.accentTint : "transparent"
    border.width: Tokens.measure.hairline
    border.color: on ? Tokens.color.accent : Tokens.color.hair

    Behavior on color {
        ColorAnimation {
            duration: Tokens.motion.feedback
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.motion.easeIn
        }
    }
    Text {
        readonly property var role: Tokens.type.button
        anchors.centerIn: parent
        text: root.on ? root.onText : root.offText
        color: root.on ? Tokens.color.accent : Tokens.color.dim
        font.family: role.family
        font.pixelSize: role.size
        font.weight: role.weight
        font.letterSpacing: role.size * role.tracking
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
    }
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
    // The shared press flash (DESIGN.md: interaction states), on press, so
    // the acknowledgement paints before the action.
    C.Feedback {
        id: pressFlash
        anchors.fill: parent
    }
    TapHandler {
        onPressedChanged: if (pressed) pressFlash.flash()
        onTapped: root.toggled()
    }
}
