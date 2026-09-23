import QtQuick
import qs.config

// The four-bar wifi strength meter: 3/6/9/12 px tall, sitting on a shared baseline.
Row {
    id: root

    // 0..100
    property real strength: 0
    property color litColor: Theme.signal
    property color unlitColor: Theme.track

    readonly property int lit: Math.min(4, Math.max(0, Math.ceil(strength / 25)))

    spacing: 2
    height: 12

    Repeater {
        model: 4

        Rectangle {
            required property int index

            width: 2
            height: 3 + index * 3
            // Row owns x; setting y directly keeps the bars on one baseline
            // without fighting it over anchors.
            y: root.height - height
            color: index < root.lit ? root.litColor : root.unlitColor
        }
    }
}
