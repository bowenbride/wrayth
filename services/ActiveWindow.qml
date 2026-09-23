pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The focused window's geometry, for anything the shell has to place against a
// window rather than against the screen. The notification stack sits inside the
// active window's top-right corner, which is the only thing that needs it so far.
//
// `Hyprland.activeToplevel` is null in this Quickshell build, so the focused
// window is found by `focusHistoryID === 0` instead -- the toplevel model
// carries the same IPC objects `hyprctl clients` returns, and `activated` reads
// false on all of them.
Singleton {
    id: root

    readonly property var ipc: {
        for (const toplevel of (Hyprland.toplevels?.values ?? [])) {
            const obj = toplevel?.lastIpcObject;
            if (obj && obj.focusHistoryID === 0)
                return obj;
        }
        return null;
    }

    // A window has to have real geometry before anything is placed against it.
    // An empty workspace falls back to the screen corner.
    readonly property bool present: {
        if (!ipc || !ipc.at || !ipc.size)
            return false;
        if (ipc.hidden)
            return false;
        return (ipc.size[0] ?? 0) > 0 && (ipc.size[1] ?? 0) > 0;
    }

    readonly property int x: present ? ipc.at[0] : 0
    readonly property int y: present ? ipc.at[1] : 0
    readonly property int width: present ? ipc.size[0] : 0
    readonly property int height: present ? ipc.size[1] : 0

    // Read live rather than assumed: `general:border_size` is configurable and
    // is drawn *outside* the geometry `at`/`size` describe. Anything placed
    // against a window insets by it, so the border stays unbroken around it.
    property int borderSize: 1

    function refreshBorder(): void {
        borderProc.running = true;
    }

    Process {
        id: borderProc

        command: ["hyprctl", "getoption", "general:border_size", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const value = JSON.parse(text).int;
                    if (value !== undefined && value >= 0)
                        root.borderSize = value;
                } catch (e) {
                // Leave the previous value standing rather than guessing.
                }
            }
        }
    }

    Component.onCompleted: {
        Hyprland.refreshToplevels();
        refreshBorder();
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n.endsWith("v2"))
                return;
            if (n === "configreloaded") {
                root.refreshBorder();
                return;
            }
            if (["activewindow", "openwindow", "closewindow", "movewindow", "resizeactive", "workspace", "moveworkspace", "focusedmon", "fullscreen", "changefloatingmode", "activespecial"].includes(n))
                Hyprland.refreshToplevels();
        }
    }
}
