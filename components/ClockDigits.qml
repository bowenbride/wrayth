import QtQuick
import qs.config

// A run of clock digits laid out at their **natural glyph widths** with an
// even **ink-to-ink** gap between them -- not in fixed cells, and not merely by
// advance either.
//
// The bar clock uses `TabularText`, which gives every digit the widest digit's
// cell so nothing beside it ever shifts. The lockscreen clock cannot: at 168px
// Chakra Petch a `1` is 64px of ink in a 110px cell, so it floated with a false
// gap either side of it. Setting the digits by advance still leaves each
// glyph's own side bearings, so a `1` next to a `0` reads with more air than a
// `4` next to a `1` -- measured 28px against 13px. So each digit is placed so
// that the clear space between its ink and its neighbour's ink is the same
// constant, whatever the two glyphs are.
//
// It exposes the ink edges of the whole run -- `inkLeft` / `inkRight`, in its
// own coordinates -- so a neighbour (the colon, the seconds) can be placed
// against the visible glyphs.
Item {
    id: root

    property string text: ""
    property real pixelSize: 168
    property color color: Theme.bright
    property int weight: Appearance.font.weightBold
    // The even clear space between one digit's ink and the next's.
    property real gap: 12

    readonly property font glyphFont: Qt.font({
        family: Appearance.font.display,
        pixelSize: root.pixelSize,
        weight: root.weight
    })

    // **Every digit measured declaratively, keyed by digit.** Re-pointing one
    // shared `TextMetrics` inside a binding and reading it back is a binding
    // loop -- Qt flagged it. Ten fixed metrics are cheap and have none. Each
    // entry is `{ x, w }`: the ink's left bearing and its width, from the
    // digit's own advance box.
    property var metricOf: ({})

    Instantiator {
        model: 10

        TextMetrics {
            id: probe

            required property int index

            font: root.glyphFont
            text: String(index)

            function publish(): void {
                const next = Object.assign({}, root.metricOf);
                next[String(probe.index)] = {
                    x: probe.tightBoundingRect.x,
                    w: probe.tightBoundingRect.width
                };
                root.metricOf = next;
            }

            onTightBoundingRectChanged: publish()
            Component.onCompleted: publish()
        }
    }

    // Left edge (advance box) of each digit, chosen so the ink of each digit
    // starts exactly `gap` past the previous digit's ink.
    readonly property var positions: {
        const out = [];
        let inkRightCursor = 0;
        for (let i = 0; i < root.text.length; i++) {
            const m = root.metricOf[root.text.charAt(i)];
            if (!m) {
                out.push(0);
                continue;
            }
            const x = i === 0 ? 0 : inkRightCursor + root.gap - m.x;
            out.push(x);
            inkRightCursor = x + m.x + m.w;
        }
        return out;
    }

    function metricAt(i: int): var {
        return root.metricOf[root.text.charAt(i)] ?? ({
                x: 0,
                w: 0
            });
    }

    readonly property real inkLeft: root.text.length ? root.positions[0] + root.metricAt(0).x : 0
    readonly property real inkRight: {
        const i = root.text.length - 1;
        if (i < 0)
            return 0;
        const m = root.metricAt(i);
        return root.positions[i] + m.x + m.w;
    }

    FontMetrics {
        id: lineMetrics

        font: root.glyphFont
    }

    // The item is exactly its ink wide; callers place it by its ink edges.
    implicitWidth: root.inkRight
    implicitHeight: lineMetrics.height

    Repeater {
        model: root.text.length

        Text {
            required property int index

            x: root.positions[index]
            // Bottom-aligned so a caller can anchor the run's baseline the way
            // it anchors the colon and the seconds.
            anchors.bottom: parent.bottom

            text: root.text.charAt(index)
            color: root.color
            font: root.glyphFont
            renderType: Text.NativeRendering
        }
    }
}
