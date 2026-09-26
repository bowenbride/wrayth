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
        if (!SystemSettings.switcher)
            return;
        if (!ShellState.switcherOpen) {
            Hyprland.refreshToplevels();
            step = by > 0 ? 1 : -1;
            ShellState.openExclusive("switcher");
        } else {
            step += by;
        }
    }
    // Focus a window. One on a regular workspace first closes any special
    // workspace open on any screen (the deck, COMM), read fresh from
    // Hyprland at that moment, so the choice lands straight on it.
    readonly property string closeSpecialsScript: 'for n in $(hyprctl monitors -j | python3 -c \'import json,sys\nfor m in json.load(sys.stdin):\n    n = m.get("specialWorkspace", {}).get("name", "")\n    if n: print(n.replace("special:", ""))\n\'); do hyprctl dispatch "hl.dsp.workspace.toggle_special(\\"$n\\")" >/dev/null; done'
    function closeSpecials(then: string): void {
        Quickshell.execDetached(["sh", "-c", `${closeSpecialsScript}; ${then}`]);
    }
    function focusWindow(t: var): void {
        if (!t)
            return;
        const focus = `hyprctl dispatch 'hl.dsp.focus({ window = "address:0x${t.address}" })' >/dev/null`;
        if ((t.workspace?.id ?? 0) > 0)
            closeSpecials(focus);
        else
            Quickshell.execDetached(["sh", "-c", focus]);
    }
    function focusWorkspace(id: int): void {
        closeSpecials(`hyprctl dispatch 'hl.dsp.focus({ workspace = ${id} })' >/dev/null`);
    }

    function commit(): void {
        if (ShellState.switcherOpen)
            commitRequested();
    }
}
