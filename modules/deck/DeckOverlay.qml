import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.modules.deck.hud
import qs.modules.deck.planner
import qs.modules.deck.signal
import qs.modules.deck.vuln
import qs.services

// The deck: one surface, one blur.
//
// A single backdrop covers the whole working area and is frosted by Hyprland as
// one region, with the four widgets drawn translucent on top of it. They have no
// blur of their own, so there are no per-panel frosted rectangles and no
// chamfer edges cut out of the frosting.
//
// The one gap is the deck terminal's slot. The terminal is a Hyprland *window*,
// and every Top layer surface draws over every window, so the backdrop leaves
// that rectangle transparent for it to show through. `ignore_alpha` on the
// namespace keeps the gap unfrosted; the terminal supplies its own translucency
// and Hyprland blurs behind it like any other window.
//
// Nothing here fades in QML. The `animation = fade` layer rule fades the whole
// surface, blur included, so it cannot slide in from an edge or leave frosting
// behind on the way out.
Variants {
    model: ShellState.screens

    PanelWindow {
        id: deck

        required property ShellScreen modelData

        readonly property int margin: Appearance.metrics.deckMargin
        readonly property int gap: Appearance.metrics.deckGap

        // Hyprland draws a window's border *outside* the geometry it reports,
        // so the terminal's visible edge lies this much further out than the
        // box it was handed. It is the compositor's own setting rather than
        // anything about the focused window; `ActiveWindow` is simply where it
        // is already kept live.
        readonly property int border: ActiveWindow.borderSize

        // **The slot is known before the deck is ever shown.** The area is
        // the monitor less what the bar reserves, read from Hyprland, not this
        // window's own size -- which is nothing until the deck first opens. So
        // the terminal can be put in its slot the moment it exists, rather than
        // sitting at whatever size it opened at until the first Super + E (on
        // a fresh install it could fill the screen behind the panels).
        readonly property real areaW: monitorIpc && reserved ? monitorIpc.width / monitorIpc.scale - reserved[0] - reserved[2] : width
        readonly property real areaH: monitorIpc && reserved ? monitorIpc.height / monitorIpc.scale - reserved[1] - reserved[3] : height
        readonly property real boxW: areaW - margin * 2
        readonly property real boxH: areaH - margin * 2

        // The bottom row's height. On a 1080p screen it is the design figure;
        // on a shorter screen it shrinks (never below a floor) so the top row --
        // the terminal and the taller SYS.DIAG column -- keeps enough room and
        // the deck does not overflow. Capped at the design height so it never
        // grows past it on a tall screen.
        readonly property real bottomH: Math.round(Math.max(200, Math.min(Appearance.metrics.deckBottomHeight, boxH * 0.30)))

        readonly property real bottomY: margin + boxH - bottomH

        // --- The terminal's outer box ---------------------------------------
        // Every edge in the deck is measured against the terminal's *outer*
        // edge, border included, because that is the edge the eye lines up with
        // a panel's frame. `termW` and `termH` are therefore the outer box; the
        // window's own geometry is this inset by the border.
        //
        // The width is not free. kitty's tab bar is a grid of whole cells, so
        // the window's width is rounded down to a multiple of one and the outer
        // box is that plus a border each side. **The panels are laid out from
        // the rounded figure, which is the fix:** the rounding used to happen
        // out of sight inside `placeTerminal`, so the bottom row was laid out
        // from the nominal width and overhung the terminal by the pixels the
        // rounding had given up.
        readonly property real termH: bottomY - gap - margin
        readonly property real termW: Deck.fitCells(boxW - gap - Appearance.metrics.deckColumnWidth - border * 2) + border * 2

        // The right column starts a gap past the terminal's outer edge and runs
        // to the margin, so the pixels the cell rounding gave up are absorbed
        // here rather than showing up as an uneven outer margin.
        readonly property real columnX: margin + termW + gap
        readonly property real columnW: margin + boxW - columnX

        readonly property real plannerW: Math.round((termW - gap) * Appearance.metrics.deckPlannerRatio)

        screen: modelData
        color: "transparent"
        // Only on the monitor the deck is showing on.
        visible: Deck.monitorName === modelData.name

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "wrayth-deck"
        // The deck terminal is the thing that wants the keyboard.
        // The terminal owns the keyboard, except while the planner's inline
        // editor is up: a gig cannot be typed without it, so the deck takes the
        // keyboard for as long as a field is open and hands it back the moment
        // it closes. Exclusive, not OnDemand, because the click that opens the
        // editor happens while focus is still None -- OnDemand would need a
        // second click to actually deliver a key.
        WlrLayershell.keyboardFocus: Planner.editing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // Only the widgets take the pointer; everything else, the terminal slot
        // included, falls through to what is underneath.
        mask: Region {
            Region {
                item: hud
            }
            Region {
                item: signal
            }
            Region {
                item: planner
            }
            Region {
                item: vuln
            }
        }

        // --- Backdrop -------------------------------------------------------
        // There isn't one. Hyprland blurs and dims the whole background behind
        // a special workspace itself -- `decoration:blur:special` and
        // `decoration:dim_special`, set in hypr-wrayth.lua -- so the deck needs
        // no backdrop of its own.
        //
        // It used to draw four rectangles around the terminal's slot, which
        // meant the unpainted gap had to match the terminal exactly. Once the
        // terminal gained a border and 16 px chamfers, a rectangular gap left
        // unblurred slivers down its right edge and at every corner. A gap that
        // does not exist cannot be the wrong shape.

        // --- Widgets --------------------------------------------------------
        Hud {
            id: hud

            x: deck.columnX
            y: deck.margin
            width: deck.columnW
            height: deck.termH
        }

        SignalPanel {
            id: signal

            x: deck.columnX
            y: deck.bottomY
            width: hud.width
            height: deck.bottomH
        }

        PlannerPanel {
            id: planner

            x: deck.margin
            y: deck.bottomY
            width: deck.plannerW
            height: deck.bottomH
        }

        VulnPanel {
            id: vuln

            x: planner.x + planner.width + deck.gap
            y: deck.bottomY
            width: deck.termW - planner.width - deck.gap
            height: deck.bottomH
        }

        // --- Terminal placement ---------------------------------------------
        // Hyprland cannot place the terminal itself: window rules are evaluated
        // in raw monitor coordinates and know nothing of reserved space.
        readonly property var monitorIpc: Hyprland.monitorFor(deck.screen)?.lastIpcObject ?? null
        readonly property var reserved: monitorIpc?.reserved ?? null
        readonly property real originX: reserved ? monitorIpc.x + reserved[0] : 0
        readonly property real originY: reserved ? monitorIpc.y + reserved[1] : 0
        readonly property string slotKey: `${originX} ${originY} ${termW} ${termH} ${border}`

        // The outer box is the slot; the window gets it inset by the border
        // Hyprland will then draw back on the outside of it.
        function placeTerminal(): void {
            if (!reserved || termW <= 0 || termH <= 0)
                return;
            // One deck places the one terminal: the one on the monitor showing
            // the deck, or -- while it is closed -- the focused one, which is
            // where Super + E will open it. Every screen's deck used to place
            // it while the deck was open, and the last one to run won.
            if ((Deck.monitorName || ShellState.focusedScreen) !== deck.modelData.name)
                return;
            Deck.placeTerminal(originX + margin + border, originY + margin + border, termW - border * 2, termH - border * 2);
        }

        Component.onCompleted: place.restart()

        // The terminal is placed as soon as its window exists -- at login, and
        // after Super + Shift + E restarts it -- deck open or not.
        Connections {
            target: Hyprland

            function onRawEvent(event: HyprlandEvent): void {
                if (event.name === "openwindow" && event.data.split(",")[2] === Deck.terminalClass)
                    place.restart();
            }
        }

        onVisibleChanged: {
            if (!visible)
                return;
            place.restart();
            // **The deck opening glitches, panel by panel.** The SYS.DIAG
            // header first, then the three panel headers behind it. The
            // scheduler runs one element at a time, so handing it the list is
            // the stagger -- each waits for the one before it.
            //
            // **This is the one stagger the animation rules allow**: these are
            // sibling panels, not children of one panel. Nothing inside a
            // panel is ever staggered against anything else inside it.
            glitchIn.restart();
        }

        // A beat after the surface is up, so the targets exist and report
        // themselves eligible before the scheduler looks for them.
        Timer {
            id: glitchIn

            interval: 220
            onTriggered: Glitch.fireSequence(["diag", "panel:signal", "panel:planner", "panel:vuln"], null)
        }
        onSlotKeyChanged: place.restart()

        Timer {
            id: place

            interval: 150
            onTriggered: deck.placeTerminal()
        }
    }
}
