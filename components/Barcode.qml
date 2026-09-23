import QtQuick
import qs.config

// One bar per pending package update, widths varying so it reads as a barcode
// rather than a meter. Capped, because the count is unbounded.
Row {
    id: root

    property int count: 0
    property int maxBars: 40
    property color barColor: Theme.mute

    readonly property int bars: Math.min(count, maxBars)

    spacing: 2

    Repeater {
        model: root.bars

        Rectangle {
            required property int index

            // Deterministic from the index, so the pattern is stable between
            // frames and only changes when the count does.
            width: 1 + (index * 7 + 3) % 3
            height: root.height
            color: root.barColor
        }
    }
}
