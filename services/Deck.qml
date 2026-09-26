pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config
import qs.services

// The deck: a Hyprland special workspace holding the wrayth-deck kitty
// window, with the shell's deck widgets shown around it. Hyprland owns whether
// it is up; the shell follows its workspace events and never guesses.
Singleton {
    id: root

    readonly property string workspace: "deck"
    readonly property string terminalClass: "wrayth-deck"

    // **The monitor the deck is showing on**, by name, or "" when it is closed.
    // It used to be read from the *focused* monitor only, so with two monitors
    // moving focus to the other screen while the deck was open hid its panels
    // on the screen still showing it, and every screen's deck surface drew its
    // panels -- and placed the terminal -- when it was open anywhere.
    readonly property string monitorName: {
        for (const m of Hyprland.monitors.values)
            if ((m.lastIpcObject?.specialWorkspace?.name ?? "") === `special:${workspace}`)
                return m.name;
        return "";
    }
    readonly property bool visible: monitorName !== ""

    onVisibleChanged: ShellState.deckVisible = visible

    // Hyprland is configured in Lua here, so a dispatch is a Lua expression
    // returning a dispatcher, not the classic `dispatcher args` string.
    // **Opening is one entrance (DESIGN.md).** Toggling the special
    // workspace straight from a key starts Hyprland's fade of the terminal at
    // once, while the panels' surface still has to be mapped and drawn --
    // measured, the panels arrived 200-270 ms behind. So the shell opens the
    // deck: it maps the panels first (`preparing`, the screen it opens on),
    // and switches the special workspace on their first frame (DeckOverlay
    // calls `reveal`), so Hyprland starts both fades together, on the same
    // curve. Closing needs no such care: both fade out from the same moment.
    property string preparing: ""
    function toggle(): void {
        if (visible || preparing !== "") {
            preparing = "";
            setOpen(false);
            return;
        }
        preparing = ShellState.focusedScreen;
        revealLimit.restart();
    }
    function reveal(): void {
        if (preparing === "")
            return;
        revealLimit.stop();
        setOpen(true);
    }
    // Never left waiting: if no frame comes, open anyway.
    Timer {
        id: revealLimit
        interval: 600
        onTriggered: root.reveal()
    }
    onMonitorNameChanged: if (monitorName !== "") preparing = ""

    // **Idempotent, and decided by Hyprland at the moment it runs.** `visible`
    // above reads a cached monitor object that is refreshed asynchronously, so
    // "close it if it is open" asked of `visible` could see a stale false and
    // do nothing -- measured: a script's cleanup left the deck open, and the
    // next run then recorded it as open and faithfully restored it that way.
    // `hl.get_active_special_workspace()` is live, the same read the Super + N
    // binds make.
    function setOpen(want: bool): void {
        const test = want ? "not (sp and sp.name == \"special:deck\")" : "sp and sp.name == \"special:deck\"";
        Hyprland.dispatch(`(function() local sp = hl.get_active_special_workspace(); if ${test} then return hl.dsp.workspace.toggle_special("${workspace}") end; return hl.dsp.no_op() end)()`);
    }

    // **Nothing the shell launches opens inside the deck.** A new window opens
    // on the monitor's active workspace, and while the deck is up that is
    // `special:deck` -- so an app from the launcher, the vuln watch's upgrade
    // terminal or anything else started with the deck showing landed behind
    // the deck terminal. Every launch goes through here: the deck is closed
    // first (the same `setOpen(false)` as `deck close`, a no-op when it is not
    // up, faded by Hyprland's own special-workspace animation) and the window
    // then opens on the regular workspace underneath, where it would have
    // opened had the deck been closed. The close goes out to Hyprland before
    // the process is even started, and a window takes far longer than that to
    // map. The deck terminal is the one window meant to be in the deck, and it
    // is not started from here.
    function leave(): void {
        setOpen(false);
    }

    function launch(command: list<string>): void {
        leave();
        Quickshell.execDetached(command);
    }

    // A width rounded down to a whole number of kitty cells. kitty's tab bar is
    // a grid of whole cells, and whatever a partial cell leaves over at each end
    // is painted separately -- which is what marked the header strip's top
    // corners. At a whole number of cells there is nothing left over, so the
    // strip and its hairline run edge to edge. It costs up to one cell of width.
    //
    // **The layout calls this, not `placeTerminal`.** The rounding used to
    // happen on the way out to Hyprland, where nothing else could see it, so
    // the panels were laid out from the nominal width and the bottom row
    // overhung the terminal by the pixels the rounding had given up. The
    // deck asks for the figure first and lays itself out from it.
    function fitCells(w: real): real {
        return Math.floor(w / Appearance.metrics.terminalCellWidth) * Appearance.metrics.terminalCellWidth;
    }

    // Puts the deck terminal exactly where the deck says. A window rule cannot
    // do this: rules are evaluated in raw monitor coordinates and know nothing
    // of the area the bars reserve, which is what the rest of the deck is laid
    // out in. The geometry passed here is the window's own -- already inset by
    // the border Hyprland draws outside it, and already a whole number of cells
    // wide.
    function placeTerminal(x: real, y: real, w: real, h: real): void {
        if (w <= 0 || h <= 0)
            return;
        // Resize first: Hyprland resizes a floating window about its centre, so
        // the move has to land it afterwards. Both no-op when the terminal is
        // not running, rather than seizing whatever window is focused.
        dispatchToTerminal(`hl.dsp.window.resize({ x = ${Math.round(w)}, y = ${Math.round(h)}, relative = false, window = w })`);
        dispatchToTerminal(`hl.dsp.window.move({ x = ${Math.round(x)}, y = ${Math.round(y)}, relative = false, window = w })`);
    }

    function dispatchToTerminal(dispatcher: string): void {
        Hyprland.dispatch(`(function() local w = hl.get_windows({ class = "${terminalClass}" })[1]; if not w then return hl.dsp.no_op() end; return ${dispatcher} end)()`);
    }

    // --- The banner follows the profile -------------------------------------
    // **Printed output cannot be recoloured, so it is reprinted.** kitty
    // re-reads its palette on a profile change and every palette-coloured cell
    // on screen changes with it -- but the logo's chromatic fringe is written
    // in *direct* colours, because fastfetch's two colour slots cannot express
    // a per-character gradient. Those cells keep the colours they were printed
    // in until something prints over them.
    //
    // `--quiet` is the whole difference from the keypress: no session bump,
    // and silence if the terminal is busy or has something typed in it. The
    // user asked for a profile, not for a refresh; a note about a terminal
    // they were not looking at is noise.
    Process {
        id: refreshProc

        command: [Paths.deckRefreshScript, "--quiet"]
    }

    // 260 ms, so the reprint lands inside the profile's own transition and
    // reads as part of the recolour rather than as a second event after it.
    Timer {
        id: refreshAfterProfile

        interval: 260
        onTriggered: refreshProc.running = true
    }

    Connections {
        target: Theme

        function onActiveProfileChanged(): void {
            refreshAfterProfile.restart();
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            // The v2 variants carry the same news with ids attached.
            if (n.endsWith("v2"))
                return;

            if (["activespecial", "workspace", "moveworkspace", "focusedmon", "openwindow", "closewindow"].includes(n))
                Hyprland.refreshMonitors();
        }
    }
}
