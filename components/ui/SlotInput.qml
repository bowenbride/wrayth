import QtQuick
import qs.config

// SlotInput (DESIGN.md): passwords and fixed-length codes. A row of equal
// boxes with 2 px gaps; unfilled `hair` border; filled `accent` border with a
// 20% `accent` fill. No caret, no focus frame, no characters shown. The
// surface owns the text (usually an off-screen TextInput) and sets `filled`.
Row {
    id: root

    property int count: 16
    property int filled: 0
    property int box: Tokens.measure.chip

    spacing: Tokens.space.s2

    Repeater {
        model: root.count
        Rectangle {
            required property int index
            readonly property bool on: index < root.filled
            width: root.box
            height: root.box
            color: on ? Tokens.color.accentFill : "transparent"
            border.width: Tokens.measure.hairline
            border.color: on ? Tokens.color.accent : Tokens.color.hair
            Behavior on color {
                ColorAnimation {
                    duration: Tokens.motion.feedback
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.motion.easeIn
                }
            }
        }
    }
}
