pragma Singleton

import QtQuick
import Quickshell

// The design tokens (DESIGN.md sections 2, 3, 4 and 9), in one place. Every
// colour, type role, spacing value, measure and timing in the shell comes
// from here; a surface that types a raw hex, pixel size or duration is a bug.
//
// Colours are the active profile's, through Theme (config/Profiles.qml holds
// the per-profile values; DESIGN.md section 2's table must match them).
Singleton {
    id: root

    // --- Colour (section 2) -------------------------------------------------
    readonly property QtObject color: QtObject {
        readonly property color ground: Theme.ground
        readonly property color deep: Theme.deep
        readonly property color panel: Theme.panel
        readonly property color panel2: Theme.panel2
        readonly property color panelHex: Theme.panelHex
        readonly property color barBg: Theme.barBg
        readonly property color hair: Theme.hair
        readonly property color text: Theme.text
        readonly property color bright: Theme.bright
        readonly property color dim: Theme.dim
        readonly property color mute: Theme.mute
        readonly property color track: Theme.track
        readonly property color signal: Theme.signal
        readonly property color accent: Theme.accent
        readonly property color alert: Theme.alert

        // The only tint strengths: 12% behind accent-framed elements, 8% for a
        // faint selected fill, 20% for filled selections inside previews.
        readonly property color accentTint: Theme.alpha(Theme.accent, 0.12)
        readonly property color accentFaint: Theme.alpha(Theme.accent, 0.08)
        readonly property color accentFill: Theme.alpha(Theme.accent, 0.20)
        // The one row-selection fill, and the hover fill.
        readonly property color rowSelected: Qt.rgba(0, 0, 0, 0.25)
        readonly property color rowHover: Qt.rgba(0, 0, 0, 0.15)
        readonly property color keycapFill: Qt.rgba(0, 0, 0, 0.35)
    }

    // --- Type (section 3) ----------------------------------------------------
    readonly property QtObject font: QtObject {
        readonly property string display: "Chakra Petch"
        readonly property string data: "JetBrains Mono"
        readonly property string japanese: "Noto Sans CJK JP"
        readonly property string icons: "Material Symbols Sharp"
        readonly property int displayWeight: 700
        readonly property int dataWeight: 400
        readonly property int japaneseWeight: 500
    }

    // A role: { family, size, tracking (em), weight }. Case is set in the
    // text itself; colour is the component's.
    function role(family: string, size: int, tracking: real, weight: int): var {
        return { family: family, size: size, tracking: tracking, weight: weight };
    }
    readonly property QtObject type: QtObject {
        readonly property var barLabel: root.role(root.font.data, 11, 0.14, 400)
        readonly property var barValue: root.role(root.font.data, 13, 0, 400)
        readonly property var clock: root.role(root.font.display, 19, 0, 700)
        readonly property var clockSeconds: root.role(root.font.display, 12, 0, 700)
        readonly property var idBlock: root.role(root.font.display, 18, 0, 700)
        readonly property var viewTitle: root.role(root.font.display, 22, 0.12, 700)
        readonly property var panelTitle: root.role(root.font.display, 20, 0.10, 700)
        readonly property var dropdownTitle: root.role(root.font.data, 12, 0.14, 400)
        readonly property var japanese: root.role(root.font.japanese, 11, 0, 500)
        readonly property var sectionLabel: root.role(root.font.data, 9, 0.18, 400)
        readonly property var rowName: root.role(root.font.data, 12, 0, 400)
        readonly property var rowMeta: root.role(root.font.data, 9, 0.12, 400)
        readonly property var rowAfter: root.role(root.font.data, 10, 0, 400)
        readonly property var body: root.role(root.font.data, 11, 0, 400)
        readonly property var secondaryBody: root.role(root.font.data, 10, 0, 400)
        readonly property var hint: root.role(root.font.data, 9, 0.12, 400)
        readonly property var button: root.role(root.font.data, 9, 0.16, 400)
        readonly property var chip: root.role(root.font.data, 9, 0.12, 400)
        readonly property var tag: root.role(root.font.data, 8, 0.10, 400)
        readonly property var keycap: root.role(root.font.data, 9, 0, 400)
        readonly property var badge: root.role(root.font.display, 11, 0, 700)
        readonly property var badgeSmall: root.role(root.font.display, 10, 0, 700)
        readonly property var largeResult: root.role(root.font.display, 30, 0, 700)
        readonly property var trackTitle: root.role(root.font.display, 15, 0.06, 700)
        readonly property var emptyState: root.role(root.font.data, 10, 0.14, 400)
        readonly property var percent: root.role(root.font.data, 10, 0, 400)
    }

    // --- Spacing and measures (section 4) --------------------------------------
    // Only these spacing values: 2, 4, 6, 8, 10, 12, 14, 16, 20, 24, 30.
    readonly property QtObject space: QtObject {
        readonly property int s2: 2
        readonly property int s4: 4
        readonly property int s6: 6
        readonly property int s8: 8
        readonly property int s10: 10
        readonly property int s12: 12
        readonly property int s14: 14
        readonly property int s16: 16
        readonly property int s20: 20
        readonly property int s24: 24
        readonly property int s30: 30
    }
    readonly property QtObject measure: QtObject {
        readonly property int hairline: 1
        readonly property int dropdownPadding: 14
        readonly property int rowGap: 4
        readonly property int rowGapPlain: 6
        readonly property int sectionGap: 12
        readonly property int row: 32
        readonly property int badgeRow: 38
        readonly property int twoLineRow: 44
        readonly property int rowPadding: 10
        readonly property int barGap: 12
        readonly property int barHeight: 44
        readonly property int barDividerHeight: 16
        readonly property int chip: 22
        readonly property int chipPadding: 8
        readonly property int toggleWidth: 58
        readonly property int toggleHeight: 22
        readonly property int buttonFull: 28
        readonly property int buttonInline: 22
        readonly property int field: 28
        readonly property int keycap: 18
        readonly property int keycapPadding: 6
        readonly property int badge: 26
        readonly property int badgeSmall: 22
        readonly property int statusDot: 5
        readonly property int iconDot: 6
        readonly property int segmentHeight: 10
        readonly property int segmentHeightLarge: 12
        readonly property int segmentGap: 2
        readonly property int segments: 20
        readonly property int percentSlot: 34
        readonly property int muteButtonWidth: 24
        readonly property int muteButtonHeight: 20
        readonly property int scrollbar: 3
        readonly property int japaneseGap: 8
        readonly property int dropdownSmall: 340
        readonly property int dropdownStandard: 400
        readonly property int dropdownWide: 520
        readonly property int tickerMin: 220
        readonly property int inputSlot: 34
        // The NET readout's live traffic graph, as built before the style pass.
        readonly property int netGraphWidth: 48
        readonly property int netGraphHeight: 16
        readonly property int netGraphPoints: 12
        // The bar's small meters beside CPU, MEM and a battery's PWR.
        readonly property int barMeterSegments: 5
        readonly property int barMeterSegmentWidth: 5
        readonly property int barMeterSegmentHeight: 13
    }
    readonly property QtObject icon: QtObject {
        readonly property int bar: 16
        readonly property int inline: 14
        readonly property int media: 16
        readonly property int chevron: 14
        readonly property int vpnLock: 10
    }
    readonly property QtObject chamfer: QtObject {
        readonly property int deck: 16
        readonly property int sysDiag: 18
        readonly property int dropdown: 12
        readonly property int cardTopRight: 14
        readonly property int cardBottomLeft: 16
        readonly property int tile: 10
        readonly property int centred: 16
        readonly property int clipboard: 14
        readonly property int footerButton: 8
        readonly property int backControl: 5
    }

    // --- Motion (section 9) -----------------------------------------------------
    readonly property QtObject motion: QtObject {
        readonly property int feedback: 120
        readonly property int movement: 180
        readonly property int panels: 250
        readonly property int wallpaper: 800
        readonly property int rise: 8
        readonly property int slide: 24
        // cubic-bezier(0.22, 1, 0.36, 1) entering; (0.4, 0, 1, 1) leaving.
        readonly property var easeIn: [0.22, 1, 0.36, 1, 1, 1]
        readonly property var easeOut: [0.4, 0, 1, 1, 1, 1]
    }
}
