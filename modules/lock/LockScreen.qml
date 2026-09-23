import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.config
import qs.services

// The session lock.
//
// Everything that is not the surface lives OUTSIDE WlSessionLock. Its default
// property is `surface`, a QQmlComponent -- a Timer or Connections written
// inside it is silently swallowed and never created, with no warning. That is
// what stranded the first real lock: authentication succeeded, the surface said
// so, and the objects meant to release the lock did not exist.
//
// **`lock.locked` is bound to `held`, and `held` survives a reload.** It used
// to be set imperatively, and that failed open: on a hot reload Quickshell
// hands the old lock connection to a new WlSessionLock whose own `locked`
// target is the default, false -- and it applies that target, which sends
// `unlock_and_destroy`. Measured: changing LockScreen.qml while locked released
// the session with no password. `held` now lives in a PersistentProperties
// declared first in this scope, so the reload restores it (true) before the
// lock object re-applies its target; engage() and release() only ever write
// `held`. Nothing writes `lock.locked` directly, so the binding is never
// broken. Verified by reloading with changed content while locked.
Scope {
    id: root

    // Must stay the first object in this scope: reload restores objects in
    // order, and this has to be restored before `lock` re-applies `locked`.
    PersistentProperties {
        id: persist

        reloadableId: "lockHeld"

        property bool held: false

        // The singletons restart with the reload, ShellState's `locked` among
        // them, so the rest of the shell is told again that the screen is
        // locked. (engage() sees `held` and does nothing.)
        onReloaded: {
            if (held)
                ShellState.locked = true;
        }
    }

    // Guards against release() re-entering itself: clearing ShellState.locked
    // fires the handler below, which would otherwise call release() again and
    // write `locked = false` a second time into a lock already tearing down.
    property bool releasing: false
    // 1 while locked, driven to 0 by the exit animation before the unlock.
    property real fade: 1
    // Our own record of holding the lock, and what `lock.locked` follows. Never
    // read `lock.locked` instead: WlSessionLock emits its change signal on lock
    // but never on unlock (it tests `isLocked()` after the lock is already
    // gone), so anything bound to it stays true for ever after the first unlock.
    property alias held: persist.held
    // How many lock surfaces currently hold the compositor's keyboard focus.
    property int focusedSurfaces: 0

    function engage(): void {
        if (held)
            return;
        exit.stop();
        releasing = false;
        fade = 1;
        Lock.reset();
        held = true;
        stranded.seconds = 0;
        refocusTries = 0;
        Lock.keyboardLost = false;
    }

    // The single way out, and safe to call more than once.
    //
    // Order matters to Hyprland. Our own flag is cleared first so the handler
    // below cannot re-enter, and `held = false` -- the unlock itself, through the binding --
    // goes last, while the surfaces are still up and rendering. Quickshell
    // destroys them afterwards; if the unlock does not reach Hyprland first, it
    // sees a locked session with no lock surfaces and paints its
    // "lockscreen has crashed" screen.
    //
    // Nothing that can throw may sit above the assignment either: WlSessionLock
    // advertises an `unlock` method that is not invokable from QML, and calling
    // it used to abandon the rest of this function.
    function release(): void {
        if (releasing || !held)
            return;
        releasing = true;
        exit.stop();

        if (ShellState.locked)
            ShellState.locked = false;

        held = false;
        releasing = false;
    }

    WlSessionLock {
        id: lock

        locked: persist.held

        surface: WlSessionLockSurface {
            // Opaque while locked, transparent only once the exit fade has
            // started. Hyprland renders the desktop behind a lock surface, so a
            // permanently transparent one would show the screen to anyone --
            // this way the dissolve lands on the live desktop, and a surface
            // whose content failed to draw still falls back to black.
            color: root.fade < 1 ? "transparent" : "black"

            LockSurface {
                anchors.fill: parent
                fade: root.fade
            }

            // Whether this surface holds the keyboard, counted for the
            // stranded-focus watchdog below.
            readonly property bool keyboardHeld: input.Window.active
            onKeyboardHeldChanged: root.focusedSurfaces += keyboardHeld ? 1 : -1
            Component.onDestruction: {
                if (keyboardHeld)
                    root.focusedSurfaces -= 1;
            }

            // The real input. The slots only draw what is typed; a Keys handler
            // on them would never see anything, the same trap the wifi
            // passphrase field hit.
            TextInput {
                id: input

                width: 1
                height: 1
                opacity: 0
                focus: true
                echoMode: TextInput.Password

                onTextChanged: Lock.buffer = text

                Keys.onReturnPressed: submit()
                Keys.onEnterPressed: submit()
                Keys.onEscapePressed: clearAll()

                function submit(): void {
                    Lock.submit();
                    text = "";
                }

                function clearAll(): void {
                    text = "";
                    Lock.clear();
                }

                // submit() takes the buffer and blanks it; the field follows, or
                // the next attempt would resend what was already tried.
                Connections {
                    target: Lock

                    function onBufferChanged(): void {
                        if (Lock.buffer === "" && input.text !== "")
                            input.text = "";
                    }
                }

                Component.onCompleted: forceActiveFocus()
            }
        }
    }

    // --- The paths in and out ---------------------------------------------

    Connections {
        target: ShellState

        function onLockedChanged(): void {
            if (ShellState.locked)
                root.engage();
            else
                root.release();
        }
    }

    Connections {
        target: Lock

        function onUnlockRequested(): void {
            exit.restart();
        }
    }

    // The whole exit runs with the surfaces up and rendering; only the last
    // step releases the lock. Fading after the unlock would be fading a surface
    // that no longer exists, and unlocking first is what Hyprland reads as a
    // crashed lockscreen.
    SequentialAnimation {
        id: exit

        // Long enough for ACCESS GRANTED to register, and no longer.
        PauseAnimation {
            duration: 200
        }

        NumberAnimation {
            target: root
            property: "fade"
            to: 0
            duration: Appearance.duration.exit
            easing.type: Easing.InCubic
        }

        ScriptAction {
            script: root.release()
        }
    }

    // --- Relaunching into a lock --------------------------------------------
    //
    // **A shell that starts while the session is locked locks again at once.**
    // `hyprctl locked` is the compositor's own answer. If it is true when this
    // process starts, the lock client that held it has gone -- killed, crashed,
    // or handed over below -- and Hyprland is showing its own "lock screen app
    // died" screen. Locking again takes the lock over (Hyprland allows it with
    // `misc:allow_session_lock_restore`, which hypr-wrayth.lua sets), and the
    // session never opens: the old client never sent an unlock.
    //
    // **The take-over is covered.** Hyprland treats any new lock as a fresh one
    // for `misc:lockdead_screen_delay` and draws the desktop until the new
    // client's first frame -- measured at three frames (~50 ms) of the desktop
    // before this was fixed. `wrayth-lock-assist cover` sets that delay to 0
    // first, so Hyprland keeps its opaque cover up until our surface arrives,
    // and `uncover` restores it once the compositor confirms the lock
    // (`lock.secure`). Only while the login session is the active one: on a
    // text console nothing is drawn to the screen anyway, and a runtime config
    // change is kept away from a session that is switched out.
    //
    // Once per process, not per hot reload: a reload keeps its own lock (see
    // the Security section), and must never take one over from another client.
    readonly property string assist: Quickshell.shellPath("external/wrayth-lock-assist")
    readonly property string sessionId: Quickshell.env("XDG_SESSION_ID") || ""
    readonly property bool supervised: Quickshell.env("WRAYTH_SUPERVISED") === "1"
    // Consecutive hand-overs to a fresh process with no keyboard gained in
    // between, kept by wrayth-lock-assist across the restarts.
    property int handovers: 0
    // Keyboard-restore attempts since the lock last held the keyboard.
    property int refocusTries: 0
    property bool covering: false

    PersistentProperties {
        id: boot

        reloadableId: "lockBoot"

        property bool probed: false

        onLoaded: {
            if (probed)
                return;
            probed = true;
            startup.running = true;
        }
    }

    Process {
        id: startup

        // `cleanup` first: a refocus helper killed outright (SIGKILL, with the
        // shell) cannot remove its temporary output, so every start does.
        command: ["sh", "-c", "\"$1\" cleanup; \"$1\" count; hyprctl locked; loginctl show-session \"$2\" -p Active --value 2> /dev/null || echo unknown", "sh", root.assist, root.sessionId || "none"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.handovers = Number(lines[0]) || 0;
                const locked = lines[1] === "true";
                const active = lines[2] !== "no";
                if (!locked || root.held) {
                    // Nothing to take over. Clear what a crash mid-take-over
                    // could have left behind.
                    root.handovers = 0;
                    assistRun.run(["count-set", "0"]);
                    assistRun.run(["uncover"]);
                    return;
                }
                if (active) {
                    root.covering = true;
                    cover.running = true;
                } else {
                    ShellState.locked = true;
                }
            }
        }
    }

    Process {
        id: cover

        command: [root.assist, "cover"]
        onExited: ShellState.locked = true
    }

    Connections {
        target: lock

        function onSecureChanged(): void {
            if (lock.secure && root.covering) {
                root.covering = false;
                assistRun.run(["uncover"]);
            }
        }
    }

    // In case the compositor never confirms, the cover is not left behind.
    Timer {
        running: root.covering
        interval: 4000
        onTriggered: {
            root.covering = false;
            assistRun.run(["uncover"]);
        }
    }

    // Fire-and-forget calls to the helper, one at a time.
    Process {
        id: assistRun

        property var queue: []

        function run(args: var): void {
            queue = queue.concat([args]);
            next();
        }
        function next(): void {
            if (running || queue.length === 0)
                return;
            command = [root.assist].concat(queue[0]);
            queue = queue.slice(1);
            running = true;
        }

        onExited: next()
    }

    // --- Keeping the keyboard ------------------------------------------------
    //
    // **After a switch to a text console and back, the lock is given its
    // keyboard back -- without restarting anything.** Hyprland re-creates its
    // keyboards on the way back but never sends our lock surface a new keyboard
    // `enter`: its seat still records the surface as focused, and every refocus
    // path it has returns early for a surface it thinks is already focused
    // (CFocusState::rawSurfaceFocus). Worse, Qt's own "window active" can stay
    // true across it (seen: a lock started while the user was on the console
    // reported the keyboard and received no keys), so the window's word is not
    // trusted. Instead, the return itself is the trigger: Hyprland announces
    // the re-created keyboards with a burst of `activelayout` events, and on
    // that burst `wrayth-lock-assist refocus` moves the focus to a temporary
    // output's lock surface and back, which is a real change, so the enter is
    // sent. No client exits, so Hyprland never shows its "lock screen app died"
    // screen. Measured: typing works straight after the return.
    //
    // The same runs if the lock has held no keyboard for 2 s while the login
    // session is active, whatever the cause. Two tries; if the keyboard is
    // still missing, the lock is handed to a fresh process -- which exits
    // without unlocking (Quickshell's lock destructor sends only `destroy`) and
    // is restarted by the supervisor, whose new lock surface Hyprland focuses on
    // arrival. **At most three hand-overs in a row without the keyboard coming
    // back**; then the respawning stops, the session stays locked, and the
    // panel says to recover from a console. Gaining the keyboard at any point
    // clears the count.
    onFocusedSurfacesChanged: {
        if (focusedSurfaces <= 0)
            return;
        refocusTries = 0;
        stranded.seconds = 0;
        Lock.keyboardLost = false;
        if (handovers > 0) {
            handovers = 0;
            assistRun.run(["count-set", "0"]);
        }
    }

    function refocus(): void {
        if (refocusProc.running || !held || Lock.granted)
            return;
        refocusTries += 1;
        refocusProc.running = true;
    }

    Process {
        id: refocusProc

        command: [root.assist, "refocus"]
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "activelayout" && root.held && !Lock.granted)
                returned.restart();
        }
    }

    // The burst is several events over a few milliseconds; act once, after
    // Hyprland has finished bringing the outputs back.
    Timer {
        id: returned

        interval: 800
        onTriggered: {
            root.refocusTries = 0;
            root.refocus();
        }
    }

    Timer {
        id: stranded

        property int seconds: 0

        interval: 1000
        repeat: true
        running: root.held && !Lock.granted && !root.releasing
        onTriggered: {
            if (root.focusedSurfaces > 0 || Lock.busy || refocusProc.running) {
                seconds = 0;
                return;
            }
            seconds += 1;
            if (seconds >= 2 && !sessionActive.running) {
                seconds = 0;
                sessionActive.running = true;
            }
        }
    }

    Process {
        id: sessionActive

        command: root.sessionId ? ["sh", "-c", "loginctl show-session \"$1\" -p Active --value && hyprctl getoption misc:allow_session_lock_restore -j", "sh", root.sessionId] : ["false"]
        stdout: StdioCollector {
            onStreamFinished: {
                const active = /^yes\s*$/m.test(text);
                if (!active || root.focusedSurfaces > 0 || Lock.busy || Lock.granted)
                    return;
                if (root.refocusTries < 2) {
                    root.refocus();
                    return;
                }
                const restorable = /"(bool|int)":\s*(true|1)\b/.test(text);
                if (!root.supervised || !restorable || root.handovers >= 3) {
                    Lock.keyboardLost = true;
                    return;
                }
                console.warn(`wrayth: the lock lost the keyboard; handing it to a fresh process (${root.handovers + 1} of 3)`);
                handover.command = [root.assist, "count-set", String(root.handovers + 1)];
                handover.running = true;
            }
        }
    }

    Process {
        id: handover

        onExited: Qt.quit()
    }

    // Last resort, **and only after a successful authentication**. The guard is
    // `Lock.granted`: this releases a lock that wedged after PAM already said
    // yes, and it can never fire on an unauthenticated lock. There is no other
    // release path -- the IPC unlock hatch was removed, because it let any local
    // process past the lockscreen without a password.
    Timer {
        interval: 1500
        repeat: true
        running: root.held && Lock.granted
        onTriggered: root.release()
    }
}
