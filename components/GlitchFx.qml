import QtQuick
import QtQuick.Effects
import QtQuick.Window
import qs.config
import qs.services

// What a glitch is applied *to*. Wrap anything that may glitch in one of
// these; it registers with `services/Glitch.qml`, which picks one target at a
// time and tells it what to play.
//
// Three effects, and they stack:
//
//   SPLIT    -- an `accent` copy and a `signal` copy drift apart for a few
//               frames and snap back. This is the design system's chromatic
//               split, animated.
//   SLICE    -- the element is cut into three horizontal bands that shift
//               sideways independently. The bands are copies of the element's
//               own rendered layer, which is why it works on a graph as well
//               as on a word.
//   SCRAMBLE -- characters flicker through junk before settling. **Text only,
//               and never a number.**
//
// **It is transparent to layout.** Nothing here changes the wrapped content's
// size or position: SPLIT and SLICE are copies drawn over it, and everything
// that moves is a transform. A `GlitchFx` that the host sizes itself sets
// `fills`, so its implicit size is not derived from its children and nothing
// can fight over who decides the width.
//
// **The whole apparatus is built only while a glitch is running.** At rest
// this is one empty `Item` and a layer that is switched off: no
// `ShaderEffectSource`, no framebuffer, no cost.
Item {
    id: root

    // How an event trigger names this target. Idle glitches do not use it.
    property string key: ""

    // Which group of the shell this belongs to, so the EFFECTS page can switch
    // whole areas on and off: `bar`, `deck`, `overlay` or `lock`.
    property string group: "overlay"

    // **May scramble.** Default off, so a target has to say that its content
    // is words before its characters are allowed to flicker.
    property bool textual: false
    // **A figure the user might act on** -- a vuln count, a percentage, a
    // rate, the clock. It may split and slice; it may never scramble. The flag
    // is here to be read at the call site as much as by the scheduler.
    property bool numeric: false

    // The host's own veto: mid-edit, disabled, showing something that must not
    // be disturbed.
    property bool active: true

    // Set on a `GlitchFx` the host gives an explicit size or anchors to.
    property bool fills: false

    // The text items SCRAMBLE rewrites. **They must carry literal text.** The
    // scramble captures each item's string, writes junk over it and writes the
    // original back, and an assignment to a QML property is the end of any
    // binding that was on it -- so a label whose text comes from a binding
    // would be frozen at whatever it said when the glitch started. Nothing
    // bound is listed here, which is also why nothing listed here is ever a
    // number: a number in this shell is always a binding.
    property var scrambleItems: []

    default property alias content: holder.data

    implicitWidth: fills ? 0 : holder.childrenRect.width
    implicitHeight: fills ? 0 : holder.childrenRect.height

    // --- State --------------------------------------------------------------
    property bool playing: false
    property var effects: []

    readonly property bool splitting: playing && effects.indexOf("SPLIT") >= 0
    readonly property bool slicing: playing && effects.indexOf("SLICE") >= 0
    readonly property bool scrambling: playing && effects.indexOf("SCRAMBLE") >= 0

    readonly property bool canScramble: root.textual && !root.numeric && root.scrambleItems.length > 0

    // A target has to be on screen to be worth glitching. `visible` is the
    // whole ancestor chain inside the window; `Window.window.visible` is
    // whether the surface itself is up, which an overlay's `visible` binding
    // decides and no `Item` property reflects.
    readonly property bool eligible: root.active && root.visible && root.width > 0 && root.height > 0 && (Window.window?.visible ?? false)

    // How far the split copies drift, in pixels. Animated out and back.
    property real drift: 0
    // The three bands' sideways offsets.
    property var bands: [0, 0, 0]

    // Reset to the right length when the count changes with the geometry.
    onBandCountChanged: root.bands = new Array(root.bandCount).fill(0)

    Component.onCompleted: Glitch.register(root)
    Component.onDestruction: Glitch.unregister(root)

    // An ineligible target that is mid-glitch has to stop, or the scheduler
    // waits for a element that is no longer on screen to finish.
    onEligibleChanged: if (!eligible && playing) root.stop()

    // --- Playing ------------------------------------------------------------
    function play(names: var, duration: int): void {
        root.effects = names;
        root.playing = true;

        if (root.splitting)
            splitOut.restart();
        if (root.slicing) {
            root.shuffleBands();
            bandTimer.restart();
        }
        if (root.scrambling)
            root.beginScramble(duration);

        life.interval = duration;
        life.restart();
    }

    function stop(): void {
        life.stop();
        bandTimer.stop();
        scrambleTimer.stop();
        root.endScramble();
        root.bands = new Array(root.bandCount).fill(0);
        // **Reversed, not cut.** The split eases back to zero rather than
        // snapping, so an interrupted glitch leaves nothing half-applied --
        // and `splitBack` runs whether or not `splitOut` finished.
        splitOut.stop();
        splitBack.restart();
        root.playing = false;
        root.effects = [];
        Glitch.release(root);
    }

    Timer {
        id: life

        onTriggered: root.stop()
    }

    // --- SPLIT --------------------------------------------------------------
    NumberAnimation {
        id: splitOut

        target: root
        property: "drift"
        to: 4
        duration: 60
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: splitBack

        target: root
        property: "drift"
        to: 0
        duration: 90
        easing.type: Easing.InCubic
    }

    // --- SLICE --------------------------------------------------------------
    // **The shift is a share of the element's width, not a constant.** At a
    // flat plus or minus 7 px, `SLICE` on a solid block moved almost no pixels
    // at all: measured on the bar's ID block, `SPLIT` peaked at 66.7 mean
    // difference against the baseline and `SLICE` at 2.2. A tear has to be a
    // fraction of the thing it is tearing, so the same effect reads the same
    // on a 40 px readout and on a 420 px panel.
    readonly property real bandReach: Math.max(6, root.width * 0.08)

    // **Two bands on a short element, three on a tall one.** Three bands of a
    // 18 px bar readout are 6 px each, which is too little of a glyph to read
    // as a tear -- it looks like noise. The bar's readouts are where most idle
    // glitches land, measured, so this is the case that decides whether the
    // effect is seen at all.
    readonly property int bandCount: root.height < 30 ? 2 : 3

    function shuffleBands(): void {
        // Independent, and one of them always stays put: every band moving
        // reads as the whole element sliding rather than as a tear.
        const pick = () => Math.round((Math.random() * 2 - 1) * root.bandReach);
        const out = [];
        for (let i = 0; i < root.bandCount; i++)
            out.push(i === Math.floor(root.bandCount / 2) ? 0 : pick());
        root.bands = out;
    }

    Timer {
        id: bandTimer

        interval: 45
        repeat: true
        onTriggered: root.shuffleBands()
    }

    // --- SCRAMBLE -----------------------------------------------------------
    // **ASCII only.** Block glyphs are not in Chakra Petch and arrive from
    // whatever Qt substitutes, with that font's metrics -- a scramble that
    // changes the width of the string is a layout change, which is the one
    // thing an effect may not be.
    readonly property string junk: "#%&@$*!?/\\<>[]{}=+~^|01XZ"

    property var captured: []
    property int settled: 0

    // An item that offers a `scramble` property is written through that and
    // keeps its bindings; anything else has its `text` captured and put back,
    // which is only safe on a literal string. See the note on `scrambleItems`.
    function sourceOf(item: var): string {
        return item.text ?? "";
    }

    function writeScramble(item: var, value: string): void {
        if (item.scramble !== undefined)
            item.scramble = value;
        else
            item.text = value;
    }

    // **Paced to the glitch, not to a fixed tick.** The characters settle left
    // to right, and at a fixed 32 ms a 150 ms glitch got four or five letters
    // in before the timer ran out and the rest of the word snapped back at
    // once. The step is the duration divided by the longest string, so the
    // word has arrived by the time the glitch ends whatever its length.
    function beginScramble(duration: int): void {
        root.captured = root.scrambleItems.map(item => root.sourceOf(item));
        root.settled = 0;
        const longest = root.captured.reduce((most, text) => Math.max(most, text.length), 1);
        scrambleTimer.interval = Math.max(16, Math.floor(duration / (longest + 1)));
        scrambleTimer.restart();
        root.paintScramble();
    }

    // Characters settle left to right, so the word arrives rather than simply
    // stopping -- the last frame before the end is the real string with one
    // junk character left in it.
    function paintScramble(): void {
        for (let i = 0; i < root.scrambleItems.length; i++) {
            const original = root.captured[i];
            let out = "";
            for (let c = 0; c < original.length; c++) {
                if (c < root.settled || original[c] === " ")
                    out += original[c];
                else
                    out += root.junk[Math.floor(Math.random() * root.junk.length)];
            }
            root.writeScramble(root.scrambleItems[i], out);
        }
    }

    function endScramble(): void {
        for (let i = 0; i < root.captured.length; i++) {
            const item = root.scrambleItems[i];
            if (!item)
                continue;
            if (item.scramble !== undefined)
                item.scramble = "";
            else
                item.text = root.captured[i];
        }
        root.captured = [];
    }

    Timer {
        id: scrambleTimer

        repeat: true
        onTriggered: {
            root.settled += 1;
            root.paintScramble();
        }
    }

    // --- The content ---------------------------------------------------------
    Item {
        id: holder

        anchors.fill: parent

        // A texture provider is what both effects copy from. It is switched on
        // only for the frames a glitch runs, so at rest this item is an
        // ordinary one with no framebuffer behind it.
        layer.enabled: root.splitting || root.slicing
        layer.smooth: false
    }

    // Everything below exists only while a glitch is running.
    Loader {
        anchors.fill: parent
        active: root.playing
        z: 1

        sourceComponent: Item {
            anchors.fill: parent

            // --- SPLIT: two tinted copies, drifting apart ------------------
            MultiEffect {
                anchors.fill: parent
                visible: root.splitting
                source: holder
                opacity: 0.55
                colorization: 1
                colorizationColor: Theme.accent

                transform: Translate {
                    x: -root.drift
                }
            }

            MultiEffect {
                anchors.fill: parent
                visible: root.splitting
                source: holder
                opacity: 0.55
                colorization: 1
                colorizationColor: Theme.signal

                transform: Translate {
                    x: root.drift
                }
            }

            // --- SLICE: three bands of the element's own layer --------------
            Repeater {
                model: root.bandCount

                Item {
                    id: slice

                    required property int index

                    readonly property real band: root.height / root.bandCount
                    // **Read here, not inside the `Translate`.** A `Translate`
                    // is not an `Item`, so `parent` inside it resolves past the
                    // delegate to the band's own parent -- which has no
                    // `index`, so the offset silently evaluated to `undefined`
                    // and every band sat still. The burst caught it: the
                    // frame-to-frame delta was the same figure eighteen times
                    // running, which a re-shuffling slice cannot be.
                    readonly property real shift: root.bands[index] ?? 0

                    y: index * band
                    width: root.width
                    height: band
                    visible: root.slicing
                    clip: true

                    transform: Translate {
                        x: slice.shift

                        Behavior on x {
                            NumberAnimation {
                                duration: 40
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    ShaderEffectSource {
                        // The whole element, pulled up so this band's slice of
                        // it lands in the clip rectangle.
                        y: -slice.index * slice.band
                        width: root.width
                        height: root.height
                        sourceItem: holder
                        live: true
                        // One of the three hides the original, so the bands are
                        // the only copy on screen and the element really is cut
                        // rather than smeared over itself.
                        hideSource: slice.index === 0 && root.slicing
                    }
                }
            }
        }
    }
}
