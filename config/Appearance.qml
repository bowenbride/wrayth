pragma Singleton

import QtQuick
import Quickshell

// Typography, spacing and geometry constants from the spec's design system.
Singleton {
    id: root

    readonly property QtObject font: QtObject {
        // Chakra Petch 500/700: titles, clock, large numbers.
        readonly property string display: "Chakra Petch"
        // JetBrains Mono 400/600: labels, readouts, body text.
        readonly property string data: "JetBrains Mono"
        // Katakana tags. The installed family is the CJK superfamily, not "Noto Sans JP".
        readonly property string accent: "Noto Sans CJK JP"
        // Icons that are somebody else's standard rather than ours -- the
        // Bluetooth rune, so far. It is the data family's own Nerd Font
        // patch, so an icon from it sits on the same metrics as the labels
        // beside it and is hinted at the sizes the bar uses.
        readonly property string icons: "JetBrainsMono Nerd Font"

        readonly property int weightMedium: 500
        readonly property int weightBold: 700
        readonly property int weightRegular: 400
        readonly property int weightSemi: 600
    }

    readonly property QtObject size: QtObject {
        readonly property int label: 11      // uppercase tracked labels
        readonly property int ticker: 11
        readonly property int date: 11
        readonly property int katakana: 12
        readonly property int workspace: 12
        // Four-letter special-workspace labels, which have to fit the same slot.
        readonly property int workspaceSpecial: 9
        readonly property int body: 13       // readout values
        readonly property int logo: 18
        readonly property int clock: 19
        // The bar clock's seconds, raised beside HH:MM in accent.
        readonly property int clockSeconds: 12
    }

    // Fixed slot widths. Every changing number on the bar sits in one of these
    // so nothing on the bar ever moves when a value updates.
    readonly property QtObject slot: QtObject {
        readonly property int percent: 38
        readonly property int memory: 92
        readonly property int netRate: 50
        readonly property int idleValue: 34
        readonly property int btName: 120
        // The AUDIO readout's device name: fixed, so switching from SPEAKERS
        // to a headset never moves the bar.
        readonly property int audioName: 96
        // The tray's item count.
        readonly property int trayCount: 16
    }

    // letter-spacing, as the em fractions the spec gives.
    readonly property real labelTracking: 0.14
    readonly property real tickerTracking: 0.04

    function tracking(pixelSize: real): real {
        return pixelSize * labelTracking;
    }

    // Digits that never change width, so fixed slots stay put. JetBrains Mono is
    // monospaced anyway; this is what keeps Chakra Petch's clock steady.
    readonly property var tabularFigures: ({
        tnum: 1,
        lnum: 1
    })

    readonly property QtObject chamfer: QtObject {
        readonly property int panel: 16
        readonly property int hud: 18
    }

    readonly property QtObject metrics: QtObject {
        readonly property int barHeight: 44
        // The ID block is a fixed width: its contents change -- the counter
        // ticks, the code is editable -- and nothing on the bar may move when
        // they do. It is also what the text is centred within.
        readonly property int idBlockWidth: 92
        // kitty's cell width at the configured font (JetBrains Mono 11pt),
        // measured with `cell_size_for_window`. The deck terminal's width is
        // rounded down to a multiple of this so kitty's tab bar grid covers
        // the whole window: the pixels a partial cell would leave over are
        // what put a mark in the header strip's top corners. If the terminal
        // font size changes, this has to change with it.
        readonly property int terminalCellWidth: 9
        readonly property int hairline: 1
        readonly property int dividerHeight: 18
        // Every hairline divider on the bar stands off whatever is beside it by
        // this, on both sides, wherever it appears -- the readout row, the
        // ticker's two end rules, and the rules' outer neighbours. One number so
        // the whole strip keeps a single rhythm and no divider reads as more of
        // a break than another.
        readonly property int dividerGap: 14
        readonly property int deckMargin: 24
        readonly property int deckGap: 24

        // The deck at 1920x1080, all measured inside the area the bar leaves so
        // the same numbers hold once Caelestia's own bar stops reserving space.
        readonly property int deckColumnWidth: 420
        // The HUD takes the terminal's height and the signal panel the bottom
        // row's, so the right column lines up with the left.
        readonly property int deckBottomHeight: 272
        readonly property real deckPlannerRatio: 0.6

        // Bar furniture
        readonly property int workspaceWidth: 34
        readonly property int workspaceHeight: 28
        readonly property int meterSegments: 5
        readonly property int meterSegmentWidth: 5
        readonly property int meterSegmentHeight: 13
        readonly property int idleButtonHeight: 28
        // Short on purpose. The ticker keeps `dividerGap` of clear air off each
        // end rule, so this ramp starts beyond that gap rather than on top of
        // it: long enough that words do not pop in, short enough that the text
        // does not begin a whole word's width further from the left rule than
        // the katakana sits from the right one.
        readonly property int tickerFade: 20
        // **The ticker never goes below this.** When the readouts would leave
        // it less, the Bluetooth readout drops to its rune alone -- nothing
        // else on the bar is squeezed.
        readonly property int tickerMin: 220
        readonly property real tickerSpeed: 30 // px per second
    }

    // **The shared animation scale.** Four durations and one easing family, and
    // every animation in the shell is on one of them. They are named for what
    // they are *for*, not for how long they are, because the point of a scale
    // is that a press flash and a hover tint are the same length wherever they
    // appear -- see the animation pass in the decisions.
    //
    //   state     press flashes, toggles, hovers, anything acknowledging input
    //   move      something travelling from one place to another
    //   panel     a panel, an overlay or a section appearing or leaving
    //   wallpaper a wallpaper cross-fade
    //
    // Entry and exit curves are Tokens.motion.easeIn and easeOut (bezier), everywhere.
    // `enter` and `exit` below are the lengths that go with them: appearing is
    // a `panel` fade with an 8 px rise, leaving is quicker, because a thing on
    // its way out has nothing left to say.
    readonly property QtObject duration: QtObject {
        readonly property int state: 120
        readonly property int move: 180
        readonly property int panel: 250
        readonly property int wallpaper: 800

        readonly property int enter: 250
        readonly property int exit: 180

        // **Not on the scale, and deliberately.** A meter easing to a new
        // reading is data settling rather than an element arriving, and 0.9 s
        // is the spec's own figure for it.
        readonly property int meter: 900
        // **Not on the scale either.** It matches Hyprland's specialWorkspace
        // animation (speed 4), so the deck and the deck terminal come up as
        // one thing; retuning it alone would pull them apart.
        readonly property int deck: 400
    }

    // The rise an appearing element fades up through. A transform, never a
    // layout change: the space is already reserved, so nothing around it moves.
    readonly property int enterRise: 8

    // Parallel items are set apart by ·; the // mark is rationed to four
    // places (the ID block, IDLE, DAEMONS // LOADED, OPERATOR // USERNAME).
    readonly property string separator: " · "
}
