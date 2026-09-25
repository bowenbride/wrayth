pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// What the bar's workspace indicator shows. The indicator is always exactly
// five slots wide, so this decides which five: the page of numbered workspaces
// holding the active one, or -- while any special workspace is visible -- the
// special workspaces themselves.
//
// Kept out of the bar component so the indicator stays pure rendering, and out
// of `Deck` so it does not depend on the deck being constructed.
//
// **Per monitor.** What is shown -- the active workspace, the page, whether a
// special workspace is up -- belongs to each bar's own monitor and lives in
// `MonitorSpaces`, one per bar; this singleton keeps what is global (the
// special workspaces' names and labels, switching, and keeping Hyprland's
// lists fresh). It used to follow the *focused* monitor, so with two monitors
// every bar lit whichever workspace had focus, including the other screen's.
Singleton {
    id: root

    readonly property int perPage: 5

    // Special workspaces carry a name; these are the ones worth a word rather
    // than the first four letters of whatever Hyprland calls them.
    readonly property var specialLabels: ({
        deck: "DECK",
        communication: "COMM",
        favourites: "FAVS",
        favorites: "FAVS"
    })

    // The bare names of every special workspace Hyprland currently knows about,
    // in a stable order so slots do not shuffle under the pointer.
    readonly property var specials: {
        const names = [];
        for (const ws of Hyprland.workspaces.values)
            if (ws.name?.startsWith("special:"))
                names.push(ws.name.slice(8));
        names.sort();
        return names;
    }

    function labelFor(name: string): string {
        return specialLabels[name] ?? name.slice(0, 4).toUpperCase();
    }

    function activate(slot: var): void {
        if (slot.empty)
            return;
        if (slot.special)
            Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${slot.target}")`);
        else
            Hyprland.dispatch(`hl.dsp.focus({ workspace = "${slot.target}" })`);
    }

    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n.endsWith("v2"))
                return;
            if (["activespecial", "workspace", "createworkspace", "destroyworkspace", "moveworkspace", "focusedmon"].includes(n)) {
                Hyprland.refreshWorkspaces();
                Hyprland.refreshMonitors();
            }
        }
    }
}
