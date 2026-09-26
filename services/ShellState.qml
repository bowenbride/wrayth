pragma Singleton

import Quickshell
import Quickshell.Hyprland
import qs.services

// Which overlays are up. IPC and keybinds flip these; the overlay modules bind
// their visibility to them. Nothing draws these yet — that starts at step 10.
Singleton {
    id: root

    // **The screens the shell draws on.** Every per-screen surface -- bar,
    // background, scanlines, deck, dropdowns, popups, launcher, picker, power
    // menu, notifications -- takes its screens from here, never from
    // `Quickshell.screens` directly. The one difference is the temporary
    // output `wrayth-lock-assist refocus` adds for a moment after a console
    // switch: it exists only so the session lock gets a second surface, and
    // nothing else may appear on it. The lock itself (WlSessionLock) still
    // covers every output, that one included, as the protocol requires.
    readonly property string refocusOutputPrefix: "WRAYTH-REFOCUS-"
    readonly property var screens: Quickshell.screens.filter(s => !String(s.name).startsWith(refocusOutputPrefix))

    // **The focused screen, by name**: Hyprland's focused monitor when it is
    // one of `screens`, else the first screen. Everything that appears on one
    // screen only -- the full-screen overlays, the volume and brightness popup,
    // notifications -- appears on this one (the overlays on the one focused
    // when they opened, see `overlayScreen`).
    readonly property string focusedScreen: {
        const name = Hyprland.focusedMonitor?.name ?? "";
        return screens.some(s => s.name === name) ? name : (screens[0]?.name ?? "");
    }

    function screenNamed(name: string): var {
        return screens.find(s => s.name === name) ?? null;
    }

    // **The screen the open full-screen overlay is on.** The launcher, the
    // power menu, the picker and the daemon library are one surface per
    // screen, and every one of them used to open -- each asking for the whole
    // keyboard, with keys landing on whichever the compositor picked. Set by
    // `openExclusive` to the focused screen at the moment of opening, and
    // kept while the overlay is up, so moving the pointer to another monitor
    // does not move it.
    property string overlayScreen: ""

    // A monitor unplugged under something open on it: that thing is closed,
    // rather than left "open" on a screen that no longer exists, holding a
    // flag that the next toggle would read as "close".
    onScreensChanged: {
        if (overlayScreen !== "" && !screenNamed(overlayScreen) && anyOverlay)
            openExclusive("");
        if (dropdown !== "" && !screenNamed(dropdownScreen))
            closeDropdown("its screen was removed");
    }

    property bool launcherOpen: false
    property bool powerOpen: false
    property bool pickerOpen: false
    // Tier 1's full-screen overlays: the screenshot selector, KEYBINDS and
    // CLIPBOARD. Exclusive of every other overlay, like the three above.
    property bool captureOpen: false
    property bool keybindsOpen: false
    property bool clipboardOpen: false
    property bool overviewOpen: false
    property bool switcherOpen: false
    property bool recordOpen: false
    // The lockscreen preview (modules/lock/LockPreview.qml): display only.
    property bool lockPreviewOpen: false
    readonly property bool anyOverlay: launcherOpen || powerOpen || pickerOpen || captureOpen || keybindsOpen || clipboardOpen || overviewOpen || switcherOpen || recordOpen || Daemons.libraryOpen
    // Which of the picker's three screens is up: "grid", "editor" or "pools".
    // It lives here rather than on the overlay so the IPC can drive it -- the
    // two inner screens are reached by clicking, and nothing in a test session
    // can click.
    property string pickerView: "grid"
    // The custom profile the editor is editing, or "" for a new one.
    property string pickerEditing: ""
    property bool locked: false

    // **Locking closes whatever was up.** The session lock draws over every
    // layer, so an overlay left open behind it is invisible -- and still
    // holding the keyboard when the lock lifts, over a screen that looks
    // ordinary. The power menu's own LOCK already closed itself; Super + L
    // and `ipc call lock lock` did not.
    onLockedChanged: if (locked) closeAll()

    // Set by the deck plumbing in step 4, from Hyprland's workspace events.
    property bool deckVisible: false

    // **Every bar, one per screen**, registered by Bar.qml. The dropdown layer
    // sizes itself against its own screen's bar, and whitelists *all* of them
    // in its focus grab, so a click on any bar's readout switches dropdowns
    // rather than counting as a click outside.
    property var barWindows: []

    function registerBar(bar: var): void {
        barWindows = barWindows.filter(b => b && b !== bar).concat([bar]);
    }

    function unregisterBar(bar: var): void {
        barWindows = barWindows.filter(b => b && b !== bar);
    }

    function barOn(screenName: string): var {
        return barWindows.find(b => b && b.screen?.name === screenName) ?? null;
    }

    // Which bar dropdown is open: "", "ident", "wifi", "bluetooth" or "power".
    property string dropdown: ""
    // **The screen it is open on.** One dropdown at a time, on the screen whose
    // bar was clicked. The dropdown layer is one surface per screen, and every
    // one of them used to open -- each taking its own focus grab. Hyprland
    // holds one grab at a time, so with two monitors the second grab ended
    // the first, which closed the dropdown about 20 ms after it opened (the
    // "opens for a frame" report).
    property string dropdownScreen: ""
    // The x of the bar readout that opened it, in bar-window coordinates. The
    // dropdown overlay shares that origin, so it can use the value directly.
    property real dropdownAnchorX: 0
    // Bumped whenever a readout toggles a dropdown, so the bar's own dismiss
    // handler can tell a click on a readout from a click on bare bar.
    property int dropdownStamp: 0
    // True while the pointer is anywhere over the bar. The dropdown's focus grab
    // waits on this; see the comment there.
    property bool barHovered: false

    // **The bar readouts that open a dropdown, registered by themselves.**
    // Each has a `dropdownName` and a `screenName`. The x a dropdown
    // hangs from is measured from the readout when it is needed, on the right
    // screen: it used to be published into one map for all screens, so a
    // second bar overwrote the first's positions with its own, and a readout
    // that moved without its own x changing left a stale value behind.
    property var readouts: []

    function registerReadout(item: var): void {
        readouts = readouts.filter(r => r && r !== item).concat([item]);
    }

    function unregisterReadout(item: var): void {
        readouts = readouts.filter(r => r && r !== item);
    }

    function readoutOn(name: string, screenName: string): var {
        return readouts.find(r => r && r.dropdownName === name && r.screenName === screenName) ?? null;
    }

    // In bar-window x, or -1 when that screen's bar has no such readout (it is
    // hidden, or not built yet).
    function anchorFor(name: string, screenName: string): real {
        const r = readoutOn(name, screenName);
        return r ? r.mapToItem(null, 0, 0).x : -1;
    }

    // A readout was clicked: open its dropdown on its own screen, or close it
    // if it is the one already open there.
    function toggleDropdown(readout: var): void {
        const name = readout.dropdownName, screenName = readout.screenName;
        if (dropdown === name && dropdownScreen === screenName) {
            closeDropdown("its readout clicked again");
        } else {
            if (dropdown === name)
                closeDropdown("the same dropdown opened on another screen");
            dropdownAnchorX = readout.mapToItem(null, 0, 0).x;
            dropdownScreen = screenName;
            dropdown = name;
        }
        dropdownStamp++;
    }

    // Opened without a click (IPC): on the given screen, under its readout if
    // it has one there.
    function openDropdown(name: string, screenName: string): void {
        if (dropdown === name && dropdownScreen !== screenName)
            closeDropdown("the same dropdown opened on another screen");
        dropdownAnchorX = Math.max(0, anchorFor(name, screenName));
        dropdownScreen = screenName;
        dropdown = name;
    }

    // **Every close says why, in the shell's log** (`qs -c wrayth log`): one
    // line naming the dropdown, how long it had been open and the reason, so a
    // "it opens and closes at once" report is diagnosable from the log alone.
    // Closing goes through `closeDropdown(reason)`; the line itself is written
    // from `onDropdownChanged`, so a close from a path that gives no reason is
    // still logged (as `unspecified`) rather than missed.
    property string _dropdownShown: ""
    property string _dropdownShownOn: ""
    property double dropdownOpenedAt: 0
    property string _closeReason: ""

    function closeDropdown(reason: string): void {
        if (dropdown === "")
            return;
        _closeReason = reason;
        dropdown = "";
    }

    function logDropdown(message: string): void {
        console.info(`wrayth: dropdown ${message}`);
    }

    onDropdownChanged: {
        const now = Date.now();
        if (_dropdownShown !== "" && _dropdownShown !== dropdown) {
            const reason = _closeReason || (dropdown !== "" ? `another dropdown opening (${dropdown})` : "unspecified");
            logDropdown(`closed: ${_dropdownShown} on ${_dropdownShownOn || "?"} after ${now - dropdownOpenedAt} ms: ${reason}`);
        }
        if (dropdown !== "" && dropdown !== _dropdownShown)
            dropdownOpenedAt = now;
        _dropdownShown = dropdown;
        _dropdownShownOn = dropdownScreen;
        _closeReason = "";
    }

    // **One overlay at a time, and this is the only way in.**
    //
    // It used to be exclusive of the launcher, the power menu and the picker
    // and of nothing else, so `daemons library open` followed by `launcher
    // open` left two `wrayth-overlay` surfaces stacked -- both asking for
    // exclusive keyboard focus, and Escape closing only the top one. The bar
    // dropdowns escaped the same fault by luck: an overlay taking the
    // keyboard clears the dropdown's focus grab, which closes it, and that
    // grab is not armed while the pointer is still on the bar.
    //
    // `daemons` is a name here like any other, so the library opens through
    // the same call rather than through a flag of its own.
    function openExclusive(which: string): void {
        if (which !== "")
            overlayScreen = focusedScreen;
        launcherOpen = which === "launcher";
        powerOpen = which === "power";
        pickerOpen = which === "picker";
        captureOpen = which === "capture";
        keybindsOpen = which === "keybinds";
        clipboardOpen = which === "clipboard";
        overviewOpen = which === "overview";
        switcherOpen = which === "switcher";
        recordOpen = which === "record";
        Daemons.libraryOpen = which === "daemons";
        // A dropdown is not an overlay, but it is a surface holding a focus
        // grab, and two things on screen asking for the keyboard is the bug
        // whatever they are called.
        if (which !== "")
            closeDropdown(`${which} opened`);
    }

    function closeAll(): void {
        openExclusive("");
        closeDropdown("everything closed (lock, launch or session action)");
    }

    // **Reaches into the custom editor from outside it.** Its swatch rows and
    // its colour picker are both pointer-driven -- a `TapHandler` and a drag --
    // and a recording has no pointer. A signal rather than a property because
    // the editor owns its own draft and nothing else should be able to hold a
    // copy of it.
    signal editorColour(string key, string hex)

    // KEYBINDS, from the IPC (a test has no pointer): start capturing new keys
    // for a bind, and answer the question a capture asked.
    signal keybindCapture(string id)
    signal keybindAnswer(bool yes)
    property string keybindPending: ""

    // Moves the picker's selection, which is what previews a profile *and*
    // lifts its card. `profile preview` only recolours the shell: the grid
    // would sit on whatever card it opened on while the colours changed
    // underneath it, which reads as the picker being broken.
    signal pickerSelect(string name)

    // Runs the pools screen's demo drag: a wallpaper from the library to a
    // profile's row, animated as a hand would move it. Demo-only, because
    // there is no pointer in a recording and this is the one gesture the
    // screen is built around.
    signal poolsDemoDrag(string file, string profile)

    // Saves the open custom editor under a name, the same call its own
    // NAME // PROFILE prompt makes. It is the fallback for a recording where
    // the typed name did not land: a video that stops halfway through a scene
    // is worse than one where the last keystroke came from somewhere else.
    signal editorSave(string name)

    // TEMPORARY (QA): the interaction states are pointer-driven and `ydotoold`
    // is not running, so there is no way to click a button from a test. This
    // lets the frame bursts drive a real ActionState through each phase.
    // Remove with the `qa` IPC handler once the states are signed off.
    signal qaAction(string kind)
}
