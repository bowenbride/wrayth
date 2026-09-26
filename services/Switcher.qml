pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Alt + Tab's state: how far along the most-recently-used list the selection
// is. `next` opens the switcher on the previous window (step 1), or moves on.
Singleton {
    id: root

    property int step: 0
    signal commitRequested

    function next(): void {
        advance(1);
    }
    function prev(): void {
        advance(-1);
    }
    function advance(by: int): void {
        if (!ShellState.switcherOpen) {
            Hyprland.refreshToplevels();
            step = by > 0 ? 1 : -1;
            ShellState.openExclusive("switcher");
        } else {
            step += by;
        }
    }
    function commit(): void {
        if (ShellState.switcherOpen)
            commitRequested();
    }
}
