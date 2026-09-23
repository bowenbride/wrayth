pragma Singleton

import Quickshell
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

    property bool launcherOpen: false
    property bool powerOpen: false
    property bool pickerOpen: false
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

    // The bar's PanelWindow, published by Bar.qml. The dropdown layer needs it
    // to size itself against the bar's width and to keep the bar clickable
    // under its focus grab.
    property var barWindow: null

    // Which bar dropdown is open: "", "wifi", "bluetooth" or "power".
    property string dropdown: ""
    // The x of the bar readout that opened it, in bar-window coordinates. The
    // dropdown overlay shares that origin, so it can use the value directly.
    property real dropdownAnchorX: 0
    // Bumped whenever a readout toggles a dropdown, so the bar's own dismiss
    // handler can tell a click on a readout from a click on bare bar.
    property int dropdownStamp: 0
    // True while the pointer is anywhere over the bar. The dropdown's focus grab
    // waits on this; see the comment there.
    property bool barHovered: false

    // **Where each bar readout is, published by the readouts themselves.**
    // `dropdown open <name>` used to hang every panel at a fixed x in the
    // middle of the bar, which is fine for a frame burst and wrong on camera.
    // A readout knows its own position; nothing else does.
    property var dropdownAnchors: ({})

    function publishAnchor(name: string, x: real): void {
        if (dropdownAnchors[name] === x)
            return;
        const next = Object.assign({}, dropdownAnchors);
        next[name] = x;
        dropdownAnchors = next;
    }

    function anchorFor(name: string): real {
        return dropdownAnchors[name] ?? 0;
    }

    function toggleDropdown(name: string): void {
        dropdown = dropdown === name ? "" : name;
        dropdownStamp++;
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
        launcherOpen = which === "launcher";
        powerOpen = which === "power";
        pickerOpen = which === "picker";
        Daemons.libraryOpen = which === "daemons";
        // A dropdown is not an overlay, but it is a surface holding a focus
        // grab, and two things on screen asking for the keyboard is the bug
        // whatever they are called.
        if (which !== "")
            dropdown = "";
    }

    function closeAll(): void {
        openExclusive("");
        dropdown = "";
    }

    // **Reaches into the custom editor from outside it.** Its swatch rows and
    // its colour picker are both pointer-driven -- a `TapHandler` and a drag --
    // and a recording has no pointer. A signal rather than a property because
    // the editor owns its own draft and nothing else should be able to hold a
    // copy of it.
    signal editorColour(string key, string hex)

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
