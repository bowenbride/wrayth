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

    // **The displayed value moves only when something you can see changes.**
    // A new value still settles over `duration.meter` on an OutCubic ease, but
    // instead of a running animation -- which kept the whole window rendering
    // at 60 fps for 900 ms of every second on the bar's CPU and memory meters,
    // for values that almost never change the lit count -- the moments the
    // ease *crosses* a segment boundary (or `hotThreshold`) are worked out in
    // advance and the displayed value steps at exactly those moments. The
    // segments light at the same times they did; in between, nothing renders.
    property real _shown: value

    property var _steps: []   // [{at: ms since epoch, v: value}], in order

    onValueChanged: _plan()
    onAnimateChanged: _plan()

    function _plan(): void {
        const a = _shown, b = value;
        _steps = [];
        stepper.stop();
        if (!animate || a === b) {
            _shown = b;
            return;
        }
        const lo = Math.min(a, b), hi = Math.max(a, b), up = b > a;
        const marks = [];
        // litSegments is round(v * segments): it changes where v * segments
        // passes k + 0.5.
        for (let k = 0; k < segments; k++) {
            const x = (k + 0.5) / segments;
            if (x > lo && x <= hi)
                marks.push(x);
        }
        if (hotThreshold >= 0 && hotThreshold > lo && hotThreshold <= hi)
            marks.push(hotThreshold);
        if (marks.length === 0) {
            _shown = b;
            return;
        }
        // OutCubic: f(t) = 1 - (1 - t)^3, so the value reaches x at
        // t = 1 - cbrt(1 - (x - a) / (b - a)).
        const now = Date.now(), total = Appearance.duration.meter;
        const steps = marks.map(x => ({
                    at: now + total * (1 - Math.cbrt(1 - (x - a) / (b - a))),
                    v: up ? x + 1e-6 : x - 1e-6
                }));
        steps.sort((p, q) => up ? p.v - q.v : q.v - p.v);
        steps.push({ at: now + total, v: b });
        _steps = steps;
        _next();
    }

    function _next(): void {
        const now = Date.now();
        while (_steps.length > 0 && _steps[0].at <= now + 1) {
            _shown = _steps[0].v;
            _steps.shift();
        }
        if (_steps.length > 0) {
            stepper.interval = Math.max(1, Math.round(_steps[0].at - now));
            stepper.restart();
        }
    }

    Timer {
        id: stepper

        onTriggered: root._next()
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
