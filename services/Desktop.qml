pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Whether the workspace on screen is being used. The wallpaper is crisp on an
// empty workspace and takes the lockscreen's blur and dim once anything is
// open, so windows sit against a quiet ground.
//
// The count comes from the *active* workspace, which is never a special one --
// the deck's windows therefore do not count, as the spec requires.
Singleton {
    id: root

    readonly property HyprlandMonitor monitor: Hyprland.focusedMonitor
    readonly property int windowCount: monitor?.activeWorkspace?.lastIpcObject?.windows ?? 0
    readonly property bool occupied: windowCount > 0

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n.endsWith("v2"))
                return;
            if (["openwindow", "closewindow", "movewindow", "workspace", "moveworkspace", "focusedmon"].includes(n)) {
                Hyprland.refreshWorkspaces();
                Hyprland.refreshMonitors();
            }
        }
    }
}
