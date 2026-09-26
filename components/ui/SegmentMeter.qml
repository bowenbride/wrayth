import QtQuick
import qs.config

// SegmentMeter (DESIGN.md): 20 segments with 2 px gaps, 10 px tall (12 px
// on the lockscreen and OSD). Lit count = round(percentage / 5), the one
// shared rule (`litFor`). Lit `signal`, unlit `track`; while muted, lit
// segments `alert`. Clickable in 5% steps when `settable`.
Item {
    id: root

    // 0..1
    property real value: 0
    property bool muted: false
    property bool large: false
    property bool settable: false
    signal picked(real value)

    function litFor(fraction: real): int {
        return Math.round(Math.max(0, Math.min(1, fraction)) * 100 / 5);
    }
    readonly property int lit: litFor(value)
    readonly property real segment: (width - (Tokens.measure.segments - 1) * Tokens.measure.segmentGap) / Tokens.measure.segments

    implicitHeight: large ? Tokens.measure.segmentHeightLarge : Tokens.measure.segmentHeight

    Row {
        anchors.fill: parent
        spacing: Tokens.measure.segmentGap
        Repeater {
            model: Tokens.measure.segments
            Rectangle {
                required property int index
                width: root.segment
                height: root.height
                color: index < root.lit ? (root.muted ? Tokens.color.alert : Tokens.color.signal) : Tokens.color.track
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
    HoverHandler {
        enabled: root.settable
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        enabled: root.settable
        onTapped: e => root.picked(Math.max(1, Math.min(20, Math.ceil(e.position.x / (root.segment + Tokens.measure.segmentGap)))) * 5 / 100)
    }
}
