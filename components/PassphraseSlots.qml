import QtQuick
import qs.config

// A segmented passphrase field: one slot lights per typed character, never the
// characters themselves. 12 slots in the wifi dropdown, 16 on the lockscreen.
Row {
    id: root

    property int slots: 12
    property int filled: 0
    property real slotWidth: 14
    property real slotHeight: 18

    spacing: 3

    Repeater {
        model: root.slots

        Rectangle {
            required property int index
            readonly property bool lit: index < root.filled

            width: root.slotWidth
            height: root.slotHeight
            color: lit ? Theme.alpha(Tokens.color.accent, 0.18) : "transparent"
            border.width: Tokens.measure.hairline
            border.color: lit ? Tokens.color.accent : Tokens.color.hair

            Behavior on color {
                ColorAnimation {
                    duration: Tokens.motion.feedback
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.motion.easeIn
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: Tokens.motion.feedback
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.motion.easeIn
                }
            }
        }
    }
}
