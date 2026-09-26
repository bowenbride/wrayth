pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Polkit
import qs.services

// The admin prompt: Wrayth as the session's polkit agent. Quickshell's agent
// does the authenticating the standard way -- the password goes to polkit's
// own setuid helper, never anywhere else -- and this only draws the question
// and passes the answer on.
//
// **One agent per session, and polkit enforces it.** If another agent (a
// polkit-gnome, hyprpolkitagent, lxpolkit...) is already registered, this one
// is refused, and it says so once rather than failing quietly; the other
// agent keeps working. Stop it, and log out and back in, to use this one.
Singleton {
    id: root

    // `WRAYTH_POLKIT=off` leaves the agent out. The test sessions set it: a
    // test shell runs inside the tester's own login session, and must never
    // become that session's agent.
    readonly property bool enabled: Quickshell.env("WRAYTH_POLKIT") !== "off"
    readonly property var agent: agentLoader.item
    readonly property bool registered: agent?.isRegistered ?? false
    readonly property bool active: previewing || ((agent?.isActive ?? false) && !!agent?.flow)
    readonly property var flow: previewing ? preview : (agent?.flow ?? null)

    // **A preview, for testing the prompt without polkit**: a stand-in
    // request drawn by the same prompt. It cannot authorise anything -- it is
    // not connected to polkit at all -- and whatever is typed into it is
    // dropped unread; submitting only reports how many characters arrived.
    property bool previewing: false
    property int previewSubmitted: -1
    QtObject {
        id: preview

        readonly property string message: "Authentication is needed to run `/usr/bin/true' as the super user"
        readonly property string actionId: "org.freedesktop.policykit.exec"
        readonly property var selectedIdentity: "unix-user:root"
        readonly property bool isResponseRequired: root.previewing
        readonly property string inputPrompt: "Password: "
        readonly property bool responseVisible: false
        readonly property string supplementaryMessage: ""
        readonly property bool supplementaryIsError: false
        readonly property bool failed: false

        function submit(value: string): void {
            root.previewSubmitted = value.length;
            root.previewing = false;
        }
        function cancelAuthenticationRequest(): void {
            root.previewSubmitted = -1;
            root.previewing = false;
        }
    }
    function startPreview(): void {
        screen = ShellState.focusedScreen;
        ShellState.openExclusive("");
        ShellState.closeDropdown("an admin prompt opened");
        previewSubmitted = -1;
        previewing = true;
    }
    // The screen the prompt is drawn on: the one focused when it arrived.
    // Every other screen is dimmed under it.
    property string screen: ""

    LazyLoader {
        id: agentLoader

        active: root.enabled
        component: PolkitAgent {
            // A request takes the keyboard outright; anything else holding it
            // -- an overlay, a dropdown -- is closed first, so there is never
            // a second surface asking for it.
            onAuthenticationRequestStarted: {
                root.screen = ShellState.focusedScreen;
                ShellState.openExclusive("");
                ShellState.closeDropdown("an admin prompt opened");
            }
        }
    }

    // Registration is settled within moments of start; if it did not happen,
    // another agent has the session.
    Timer {
        interval: 4000
        running: true
        onTriggered: {
            if (root.enabled && !root.registered)
                once.running = true;
        }
    }
    // Once per login, not on every shell restart: marked in the runtime dir,
    // which the session's end clears.
    Process {
        id: once

        command: ["sh", "-c", 'mkdir -p "$1" && [ ! -e "$1/polkit-noted" ] && touch "$1/polkit-noted"', "sh", `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/wrayth`]
        onExited: code => {
            if (code === 0)
                Notifications.send("Admin prompts: another agent is in charge",
                    "Another polkit agent is already running in this session, so Wrayth's admin prompt is not in use. Admin prompts still work through the other one.");
        }
    }

    // The program a request is for, when polkit says: pkexec's own messages
    // name it ("... to run `/usr/bin/foo' as ..."), other actions do not.
    function programOf(message: string): string {
        const m = /[`'"](\/[^`'"\s]+)[`'"]/.exec(message ?? "");
        return m ? m[1] : "";
    }

    function identityName(identity: var): string {
        if (!identity)
            return "";
        const s = String(identity.displayName ?? identity.name ?? identity);
        return s.replace(/^unix-user:/, "").replace(/^unix-group:/, "group ");
    }
}
