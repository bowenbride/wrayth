import QtQuick
import qs.config

// A run of discrete segments: the bar's 5-segment CPU meter, the HUD's
// 20-segment memory bar, the battery bar, the volume bar.
Row {
    id: root

    // 0..1.
    property real value: 0
    property int segments: 5
    property real segmentWidth: 4
    property real segmentHeight: 10
    property color litColor: Theme.signal
    property color unlitColor: Theme.track
    // Segments at or past this fraction light in accent instead.
    property real hotThreshold: -1
    property color hotColor: Theme.accent
    property bool animate: true

    property real _shown: value

    Behavior on _shown {
        enabled: root.animate
        NumberAnimation {
            duration: Appearance.duration.meter
            easing.type: Easing.OutCubic
        }
    }

    // **The one rule every segmented meter in the shell lights by.** The number
    // of lit segments is `round(value * segments)`, clamped to the run -- which,
    // on the 20-segment 5%-per-step volume and brightness bars, is exactly
    // `round(percentage / 5)` against the same whole percentage shown as text.
    // Rounding (not a `>` on the raw float) is what keeps a PipeWire volume that
    // reads 0.0500001 at one segment rather than two, and 95% at nineteen
    // rather than a full twenty.
    readonly property int litSegments: Math.max(0, Math.min(segments, Math.round(_shown * segments)))

    spacing: 2

    Repeater {
        model: root.segments

        Rectangle {
            required property int index

            width: root.segmentWidth
            height: root.segmentHeight
            // A segment lights once it falls within the lit count.
            readonly property bool lit: index < root.litSegments
            readonly property bool hot: root.hotThreshold >= 0 && root._shown >= root.hotThreshold

            color: lit ? (hot ? root.hotColor : root.litColor) : root.unlitColor

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.duration.state
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
