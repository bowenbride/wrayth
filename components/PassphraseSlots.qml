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
            color: lit ? Theme.alpha(Theme.accent, 0.18) : "transparent"
            border.width: Appearance.metrics.hairline
            border.color: lit ? Theme.accent : Theme.hair

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.duration.state
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on border.color {
                ColorAnimation {
                    duration: Appearance.duration.state
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
