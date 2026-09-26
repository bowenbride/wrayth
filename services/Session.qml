pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.services

// The power menu's tiles and what they do. Reboot and power off are armed by a
// first press and only run on a second, so neither is one keystroke away.
Singleton {
    id: root

    readonly property var tiles: [
        {
            id: "lock",
            label: "LOCK",
            key: "L",
            katakana: "施錠",
            confirm: false
        },
        {
            id: "logout",
            label: "LOG OUT",
            key: "E",
            katakana: "切断",
            confirm: true
        },
        {
            id: "sleep",
            label: "SLEEP",
            key: "S",
            katakana: "休止",
            confirm: false
        },
        {
            id: "reboot",
            label: "REBOOT",
            key: "R",
            katakana: "再起動",
            confirm: true
        },
        {
            id: "poweroff",
            label: "POWER OFF",
            key: "P",
            katakana: "停止",
            confirm: true
        }
    ]

    property int selected: 0
    // The tile id waiting on a second press, cleared when the countdown runs out.
    property string armed: ""
    // The tile whose action is under way, so it can wear the working state.
    // LOCK and SLEEP hand off to something that takes a moment; LOG OUT ends
    // the session outright.
    property string running: ""
    property string status: "READY"

    readonly property int confirmMs: 4000

    function move(delta: int): void {
        selected = (selected + delta + tiles.length) % tiles.length;
        armed = "";
        status = "READY";
    }

    // Escape, a click off the tiles, or the countdown running out all land
    // here: the armed tile stands down and the menu is whole again, without
    // closing. Only used while something is armed; closing is a separate act.
    function disarm(): void {
        armed = "";
        countdown.stop();
        status = "READY";
    }

    function selectKey(key: string): void {
        const index = tiles.findIndex(tile => tile.key === key.toUpperCase());
        if (index < 0)
            return;
        if (index !== selected) {
            selected = index;
            armed = "";
        }
        activate();
    }

    function activate(): void {
        const tile = tiles[selected];
        if (!tile)
            return;

        if (tile.confirm && armed !== tile.id) {
            armed = tile.id;
            status = `CONFIRM ${tile.label}`;
            countdown.restart();
            return;
        }

        armed = "";
        countdown.stop();
        status = `EXECUTING ${tile.label}`;
        run(tile.id);
    }

    function run(id: string): void {
        running = id;
        switch (id) {
        case "lock":
            close();
            ShellState.locked = true;
            break;
        case "logout":
            // **Logging out ends the session, not just Hyprland.** Exiting
            // Hyprland alone left anything the shell had launched running
            // with no display -- an Electron app's main process, VSCodium
            // for one, survived with no window and held its single-instance
            // lock, so it would not open again after logging back in (logind
            // keeps a closed session's processes unless KillUserProcesses is
            // set, and Arch leaves it off). So Hyprland is asked to exit
            // first, which lets apps close normally, and a few seconds later
            // logind ends the session, which sends SIGTERM to whatever is
            // left. Only ever this login's own session: the id comes from
            // XDG_SESSION_ID alone and nothing is done without it (the test
            // sessions run inside the tester's login and never set it).
            Quickshell.execDetached(["sh", "-c", 'id="$1"; hyprctl dispatch "hl.dsp.exit()" > /dev/null 2>&1; [ -n "$id" ] || exit 0; sleep 3; exec loginctl terminate-session "$id"',
                "sh", Quickshell.env("XDG_SESSION_ID") ?? ""]);
            break;
        case "sleep":
            Quickshell.execDetached(["systemctl", "suspend"]);
            close();
            break;
        case "reboot":
            Quickshell.execDetached(["systemctl", "reboot"]);
            break;
        case "poweroff":
            Quickshell.execDetached(["systemctl", "poweroff"]);
            break;
        }
    }

    function open(): void {
        running = "";
        selected = 0;
        armed = "";
        status = "READY";
        countdown.stop();
        ShellState.openExclusive("power");
    }

    function close(): void {
        armed = "";
        countdown.stop();
        ShellState.closeAll();
    }

    // No second press within three seconds and the tile disarms itself.
    Timer {
        id: countdown

        interval: root.confirmMs
        onTriggered: {
            root.armed = "";
            root.status = "READY";
        }
    }
}
