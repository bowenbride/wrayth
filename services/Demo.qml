pragma Singleton

import QtQuick
import Quickshell
import qs.config
import qs.services

// Demo mode: what the shell shows while it is being recorded.
//
// **It exists so a showcase video does not publish the user's life.** A
// recording of this shell would otherwise carry the home network's name, every
// neighbouring network the Wi-Fi scan turned up, the paired headphones, the
// hostname, and whatever is written in the planner -- none of which is the
// point of the video and all of which is on screen at once.
//
// Three rules, and they are the whole design:
//
//  1. **It masks, it never writes.** Every placeholder below is a display
//     string. `Planner`'s file, `Wifi`'s connection list and `Machine`'s real
//     hostname are untouched, so nothing here can survive into the user's
//     data. The one exception is `~/.cache/wrayth/status`, which the deck
//     terminal's greeting reads -- that is a cache the shell rewrites
//     constantly, and it is put back the moment demo mode ends.
//  2. **It is never the shell's resting state.** A config reload rebuilds this
//     singleton with `active` false, which is the safe direction: the worst a
//     reload can do is end demo mode early and show real data to a camera that
//     is still running, and that is a retake rather than a leak.
//  3. **It cannot get stuck on.** The script that drives it pings; without a
//     ping it switches itself off. A crashed recorder must not leave the user
//     with their notifications held back and a fake network name on the bar.
Singleton {
    id: root

    property bool active: false

    // --- The watchdog --------------------------------------------------------
    // **The single most important line in this file.** Demo mode holds real
    // notifications back. A script killed with SIGKILL runs no trap, so the
    // shell has to be the one that gives up. The driver pings every few
    // seconds; `expirySeconds` is a ceiling, not a schedule.
    property int expirySeconds: 300

    // **`begin` and `end` own the whole of it.** The first version left the
    // glitch veto to the IPC handler, so a watchdog expiry restored the
    // masking and the held notifications and left the schedule silenced --
    // the exact "stuck on" state the watchdog exists to prevent, for one of
    // the three things it covers. Anything demo mode changes is changed here.
    function begin(seconds: int): void {
        root.expirySeconds = seconds > 0 ? seconds : 300;
        root.active = true;
        Glitch.suppressed = true;
        // The sequence opens with the lines off, whatever the user runs.
        root.scanlines = "NONE";
        root.ping();
    }

    function ping(): void {
        if (!root.active)
            return;
        watchdog.interval = root.expirySeconds * 1000;
        watchdog.restart();
    }

    function end(): void {
        watchdog.stop();
        root.active = false;
        root.messagesForced = false;
        root.messagesUnread = false;
        root.scanlines = "";
        Glitch.suppressed = false;
        Notifications.releaseHeld();
    }

    Timer {
        id: watchdog

        onTriggered: {
            console.warn(`wrayth: demo mode expired after ${root.expirySeconds}s with no ping; restoring`);
            root.end();
        }
    }

    // --- Placeholders --------------------------------------------------------
    // Chosen to be plausible rather than obviously fake: a video full of
    // `XXXX` reads as redacted, which is its own kind of distracting. None of
    // them names anything real.
    readonly property string hostPlaceholder: "archlab"
    readonly property string userPlaceholder: "runner"
    readonly property string ssidPlaceholder: "HOMELAB"
    readonly property string devicePlaceholder: "HEADSET"
    // **Not on the brief's list, and added anyway.** The deck terminal's
    // greeting opens `Good evening, <handle>` -- the user's own first name, in
    // the middle of the frame, in the scene the whole video is built around.
    // It is the same kind of detail as the hostname and it would have been an
    // odd thing to leave in.
    readonly property string handlePlaceholder: "Runner"

    function handle(real: string): string {
        return root.active ? root.handlePlaceholder : real;
    }

    // The bar's ID block. Two characters each side of the `//`, which is what
    // the block is built to draw -- it renders as `RN//07`, not `RN.07`.
    readonly property string codePlaceholder: "RN"
    readonly property string suffixPlaceholder: "07"

    function code(real: string): string {
        return root.active ? root.codePlaceholder : real;
    }

    function suffix(real: string): string {
        return root.active ? root.suffixPlaceholder : real;
    }

    // **The shell prompt, in every terminal that is already open.** `\u` and
    // `\h` are bash's own escapes and cannot be overridden, so `_wrayth_prompt`
    // substitutes these strings instead -- and because it re-reads the status
    // cache on every prompt, a terminal that was open before the recording
    // started picks the masked identity up at its next line rather than
    // needing to be restarted.
    function promptIdentity(user: string, host: string): string {
        if (!root.active)
            return `${user}@${host}`;
        return `${root.userPlaceholder}@${root.hostPlaceholder}`;
    }

    // The deck terminal's fetch header, which is the one masked value that has
    // to reach outside the shell. `StatusCache` writes it; `_wrayth_fetch`
    // exports it; `fastfetch.jsonc`'s title reads it.
    function fetchTitle(user: string, host: string): string {
        if (!root.active)
            return `${user}@${host}`;
        return `${root.userPlaceholder}@${root.hostPlaceholder}`;
    }

    function host(real: string): string {
        return root.active ? root.hostPlaceholder : real;
    }

    // The connected network. Everything that draws `UPLINK <name>` goes
    // through this -- the bar ticker, the HUD and the lockscreen.
    function ssid(real: string): string {
        if (!root.active || !real)
            return real;
        return root.ssidPlaceholder;
    }

    // **The scan list is the bigger leak, and it was not in the brief.** One
    // network name says where you are to somebody who knows it; eleven of
    // your neighbours' names say it to anybody with a wardriving database.
    // The list is masked by position so it does not shuffle between frames,
    // and the connected one keeps the same placeholder it has everywhere else.
    function ssidAt(real: string, index: int, connected: bool): string {
        if (!root.active || !real)
            return real;
        if (connected)
            return root.ssidPlaceholder;
        return `NET-${String(index + 1).padStart(2, "0")}`;
    }

    function device(real: string, index: int): string {
        if (!root.active || !real)
            return real;
        return index <= 0 ? root.devicePlaceholder : `DEVICE-${String(index + 1).padStart(2, "0")}`;
    }

    // **The whole list is substituted, not just the names.** Masking names one
    // by one left the real list's *shape* on screen -- how many gigs there
    // are, how many are done, what the tags say -- which is most of what a
    // planner tells you about somebody. This is a day in the life with no
    // franchise names and no places, and the counts on the bar and in the
    // deck header follow it because `Planner` reads them from here too.
    readonly property var tasks: [
        {
            name: "Breakfast",
            tag: "LIFE",
            done: true
        },
        {
            name: "Shower",
            tag: "LIFE",
            done: true
        },
        {
            name: "System audit",
            tag: "SEC",
            done: false
        },
        {
            name: "Patch firmware",
            tag: "OPS",
            done: false
        },
        {
            name: "Client handoff",
            tag: "GIG",
            done: false
        },
        {
            name: "Night market run",
            tag: "LIFE",
            done: false
        }
    ]

    // --- The scanline treatment ----------------------------------------------
    // **An override, not a setting.** The sequence opens with the lines off
    // whatever the user runs, and switches them on in scene 8 -- and doing
    // that through `Effects.setScanlines` would write the user's
    // `effects.json` twice to take a video. `Effects` reads this instead
    // while demo mode is on; the file is never touched.
    property string scanlines: ""

    function setScanlines(key: string): void {
        root.scanlines = key;
    }

    // --- The message indicator ----------------------------------------------
    // **The shell still never reads a message.** This forces the one bit the
    // indicator draws and nothing else -- there is no content here to fake,
    // because there is no content anywhere in this shell to begin with.
    property bool messagesForced: false
    property bool messagesUnread: false

    function forceMessages(state: string): string {
        if (state === "off") {
            root.messagesForced = false;
            root.messagesUnread = false;
            return "off";
        }
        root.messagesForced = true;
        root.messagesUnread = state === "unread";
        return root.messagesUnread ? "unread" : "read";
    }
}
