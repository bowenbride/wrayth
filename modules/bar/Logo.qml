import QtQuick
import qs.components
import qs.config
import qs.services

// The ID block: the runner's two-character code, then a two-character suffix.
// `BO//01`, in ground on accent, right edge slanted. Both halves are the user's
// to set; nothing here ticks, which is why the block can size to exactly the
// text it shows.
//
// The block is part of the bar's structure rather than an element sitting
// inside it: the bar places it flush against the screen's left edge and the top,
// and it runs the full height down to the bar's bottom border, so it and the
// accent line beneath it read as one connected shape.
//
// **The text is three groups, not one tracked string.** One string cannot pull
// the slashes together while leaving the code and count evenly spaced, and Qt
// adds letter spacing after the *last* character of a run as well, which pushes
// each group's box past its last glyph and skews the gaps between them. Each
// group therefore ends at its last glyph, and the three are placed from their
// measured ink rather than from their advance boxes.
SlantBlock {
    id: root

    // The saved values only. The editor does not reach in here while it is
    // open: what the block shows is what is on disk, and it changes when APPLY
    // changes it.
    // Masked for a recording. The saved values are untouched -- `Runner`'s
    // file is never written by demo mode, only drawn over.
    readonly property string codeText: Demo.code(Runner.code)
    readonly property string countText: Demo.suffix(Runner.suffix)

    // The gap either side of the slashes, between real ink at mid-height --
    // and, after the slashes, to the counter's reserved box rather than to its
    // digits, so the block does not breathe as the count ticks. The mark is a
    // separator inside one word, so it sits closer to what it separates than
    // the block sits to its own edges. **Both gaps coming out equal is the
    // acceptance test, not this figure.**
    //
    // This spaces the three groups only. It has nothing to do with the
    // tracking inside them, which is `font.letterSpacing` on each Text.
    readonly property real gap: 4.5
    // Red either side of the text: 14 px left of the code's ink, and 14 px
    // from the counter's box to the nearest point of the slant.
    readonly property real sidePadding: 14

    // Where the slashes' ink sits relative to their own advance box. These are
    // properties of the glyph pair at this size and tracking, measured on
    // screen; the gaps above are the acceptance test.
    //
    // **They are the extremes of the ink, not its mid-height edges**, and a
    // `/` leans, so its extremes are at opposite corners: furthest right at
    // the top, furthest left at the bottom. Both were originally measured at
    // the waist, and both were wrong in the same way -- each side of the mark
    // was under-spaced where the neighbouring glyph happened to meet it.
    //
    // On the right the suffix's leading character often reaches left at the
    // top, exactly where the slash reaches right: at a nominal gap of 5 that
    // side still rasterised to 2 px of clearance against the left's 4.
    //
    // On the left the slash closes on the code as it descends, so the gap
    // narrowed steadily downward -- an ID like `AB//01` measured 9 px at the cap line
    // falling to 4 at row 23, a five-row tight run low down, while the right
    // side was tight only at the top and then opened out. The mark read as
    // leaning into the code and away from the suffix. **Raising the gap could
    // not fix either, because it moves both sides at once.**
    //
    // Judged by the area of the gap rather than its narrowest row, which is
    // what the eye actually reads: it now measures 109 px^2 on each
    // side, on all six profiles.
    readonly property real slashInkLeft: 1.5
    readonly property real slashInkRight: 2.5

    // Sized to its text. This is the only element on the bar whose width
    // changes; everything to its right keeps its size and simply shifts, and
    // the ticker gives or takes the difference.
    // From the suffix's last ink to the nearest point of the slant.
    implicitWidth: root.countInkEnd + root.sidePadding + slant
    implicitHeight: Appearance.metrics.barHeight - Appearance.metrics.hairline
    fillColor: Theme.accent
    slant: 14

    // --- Measurement ------------------------------------------------------
    TextMetrics {
        id: mCode

        font: codeLabel.font
        text: root.codeText
    }

    TextMetrics {
        id: mSlash

        font: slashLabel.font
        text: "//"
    }

    TextMetrics {
        id: mCount

        font: countLabel.font
        text: root.countText
    }

    // Each group's width ends at its last glyph: the advance minus the trailing
    // letter spacing Qt added after it.
    readonly property real codeWidth: mCode.advanceWidth - codeLabel.font.letterSpacing
    readonly property real slashWidth: mSlash.advanceWidth - slashLabel.font.letterSpacing
    readonly property real countWidth: mCount.advanceWidth - countLabel.font.letterSpacing

    // Ink insets inside each group's box, which differ per glyph -- `L` leaves
    // more air on its right than `O` does, and `1` more on its left than `0`.
    readonly property real codeInkRight: root.codeWidth - (mCode.tightBoundingRect.x + mCode.tightBoundingRect.width)
    readonly property real codeInkLeft: mCode.tightBoundingRect.x
    readonly property real countInkLeft: mCount.tightBoundingRect.x
    readonly property real countInkRight: root.countWidth - (mCount.tightBoundingRect.x + mCount.tightBoundingRect.width)


    // --- Layout -----------------------------------------------------------

    // **The ink boundaries are quantised, not the boxes.** Rounding each text
    // item's x independently let the fractional part of the glyph metrics leak
    // into the gaps, and the same spacing rasterised as 7 px or 8 depending on
    // the code. Each boundary is rounded to a whole pixel first, and the next
    // group is placed 7 px from *that*.
    readonly property real codeInkStart: root.sidePadding
    readonly property real originX: root.codeInkStart - root.codeInkLeft
    readonly property real codeInkEnd: Math.round(root.originX + root.codeWidth - root.codeInkRight)

    readonly property real slashInkStart: root.codeInkEnd + root.gap
    readonly property real slashX: root.slashInkStart - root.slashInkLeft
    readonly property real slashInkEnd: Math.round(root.slashX + root.slashWidth - root.slashInkRight)

    readonly property real countInkStart: root.slashInkEnd + root.gap
    readonly property real countX: root.countInkStart - root.countInkLeft
    readonly property real countInkEnd: Math.round(root.countX + root.countWidth - root.countInkRight)

    Text {
        id: codeLabel

        x: root.originX
        // The one group that is placed; the other two hang off its baseline.
        anchors.verticalCenter: parent.verticalCenter

        text: root.codeText
        color: Theme.ground
        font.family: Appearance.font.display
        font.pixelSize: Appearance.size.logo
        font.weight: Appearance.font.weightBold
        font.letterSpacing: Appearance.size.logo * 0.06
        renderType: Text.NativeRendering
    }

    // Pulled tight so the two strokes read as one `//` mark.
    Text {
        id: slashLabel

        x: root.slashX
        // **Baseline, not a vertical centre of its own.** Three independent
        // centres happen to agree only while all three groups share a font and
        // size, and stop agreeing the moment one of them does not.
        anchors.baseline: codeLabel.baseline

        // **Only the separator is dimmed.** The code and the suffix are both
        // solid ground: `BO//01` is one name, not a name with a footnote, and
        // dimming the suffix as well said the second half was secondary.
        opacity: 0.4
        text: "//"
        color: Theme.ground
        font.family: Appearance.font.display
        font.pixelSize: Appearance.size.logo
        font.weight: Appearance.font.weightBold
        font.letterSpacing: Appearance.size.logo * -0.12
        renderType: Text.NativeRendering
    }

    Text {
        id: countLabel

        x: root.countX
        anchors.baseline: codeLabel.baseline

        text: root.countText
        color: Theme.ground
        font.family: Appearance.font.display
        font.pixelSize: Appearance.size.logo
        font.weight: Appearance.font.weightBold
        font.letterSpacing: Appearance.size.logo * 0.06
        renderType: Text.NativeRendering
    }


    // Published so `dropdown open ident` can hang the panel where a click
    // would have. `mapToItem` is a function call, so it is re-read from a
    // handler rather than bound -- a binding through it captures whatever it
    // returned the first time and never runs again.
    function _publish(): void {
        ShellState.publishAnchor("ident", root.mapToItem(null, 0, 0).x);
    }

    onXChanged: root._publish()
    onWidthChanged: root._publish()
    Component.onCompleted: Qt.callLater(root._publish)

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        onClicked: {
            // Where the dropdown hangs from, the same as the other readouts.
            ShellState.dropdownAnchorX = root.mapToItem(null, 0, 0).x;
            // **Through `toggleDropdown`, like every other readout.** It bumps
            // `dropdownStamp`, which is what lets the bar's own dismiss
            // handler tell a click on a readout from a click on bare bar.
            // Setting the property directly happened to work only because
            // this is a `MouseArea` and consumes the press where the other
            // readouts use a `TapHandler` that lets it through -- a latent
            // bug that comes true the moment the handler type changes.
            ShellState.toggleDropdown("ident");
        }
    }
}
