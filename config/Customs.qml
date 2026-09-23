pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// The user's own colour profiles, in ~/.config/wrayth/custom-profiles.json.
//
// Only the nine authored colours are stored. The rest of a palette is a set of
// fixed relationships between those nine -- see `Profiles.derive` -- so storing
// them would be storing a derivation, and a hand edit could then contradict
// itself. `Profiles` is what merges these with the six presets; nothing else in
// the shell has to know which kind of profile it is holding.
Singleton {
    id: root

    // [{ name, created, colors: { ground, panel, hair, text, bright, dim,
    //                             signal, accent, alert } }], creation order.
    property var list: []

    readonly property var names: root.list.map(entry => entry.name)

    // The nine, in the order the editor lists them. The role text is the
    // editor's, so it lives with the key rather than in the view.
    readonly property var roles: [
        {
            key: "ground",
            role: "BASE BACKGROUND"
        },
        {
            key: "panel",
            role: "PANEL AND CARD FILL"
        },
        {
            key: "hair",
            role: "BORDERS"
        },
        {
            key: "text",
            role: "BODY TEXT"
        },
        {
            key: "bright",
            role: "TITLES, KEY VALUES"
        },
        {
            key: "dim",
            role: "LABELS"
        },
        {
            key: "signal",
            role: "DATA, GRAPHS, KATAKANA"
        },
        {
            key: "accent",
            role: "ACTIVE, HOT, SELECTED"
        },
        {
            key: "alert",
            role: "WARNINGS ONLY"
        }
    ]

    // The background colours, whose contrast is judged against TEXT rather
    // than against GROUND.
    readonly property var backgroundKeys: ["ground", "panel", "hair"]

    function find(name: string): var {
        for (const entry of list)
            if (entry.name.toLowerCase() === name.toLowerCase())
                return entry;
        return null;
    }

    function has(name: string): bool {
        return find(name) !== null;
    }

    // Add a new profile or replace an existing one, keeping its place in the
    // creation order so the picker's cards do not shuffle when one is edited.
    function store(name: string, colors: var): void {
        const next = list.slice();
        const at = next.findIndex(entry => entry.name.toLowerCase() === name.toLowerCase());
        if (at >= 0)
            next[at] = Object.assign({}, next[at], {
                name,
                colors
            });
        else
            next.push({
                name,
                created: Date.now(),
                colors
            });
        list = next;
        write();
    }

    function remove(name: string): void {
        list = list.filter(entry => entry.name.toLowerCase() !== name.toLowerCase());
        write();
    }

    // See `Wallpapers.loaded`: a reload rebuilds this with an empty list and
    // the file loads asynchronously, so a write in that window would delete
    // every custom profile the user has.
    property bool loaded: false

    function write(): void {
        if (!root.loaded)
            return;
        file.setText(`${JSON.stringify({
            profiles: root.list
        }, null, 2)}\n`);
    }

    function adopt(contents: string): void {
        // An empty file is a valid "no custom profiles", and it counts as
        // read -- otherwise the first save would be refused for ever.
        if (!contents.trim()) {
            list = [];
            loaded = true;
            return;
        }
        try {
            const parsed = JSON.parse(contents);
            const profiles = parsed?.profiles;
            if (!Array.isArray(profiles)) {
                loaded = true;
                return;
            }
            // A hand-edited file is not trusted to be complete **or safe**: an
            // entry without a name or without all nine colours would produce a
            // profile the shell could not paint with, and -- the security part
            // -- a profile name or a colour is not just displayed. The name is
            // written into `~/.cache/wrayth/status` (which the deck greeting
            // sources as shell) and used to build a wallpaper path; the colours
            // are interpolated into a `hyprctl eval` Lua string. So both are
            // validated to the same charset the editor enforces, and any entry
            // that fails is dropped rather than loaded. This is the single point
            // that keeps a crafted colour like `")); os.execute(...)` or a name
            // like `x=y;id` or `../../evil` out of every downstream sink.
            const nameOk = n => typeof n === "string" && /^[A-Za-z0-9 -]{1,40}$/.test(n);
            const hexOk = c => typeof c === "string" && /^#[0-9A-Fa-f]{6}$/.test(c);
            list = profiles.filter(entry => entry && nameOk(entry.name) && entry.colors && root.roles.every(r => hexOk(entry.colors[r.key])));
            loaded = true;
        } catch (e) {
            console.warn(`wrayth: custom-profiles.json is not readable JSON (${e})`);
        }
    }

    FileView {
        id: file

        path: Paths.customProfilesFile
        watchChanges: true
        printErrors: false

        onLoaded: root.adopt(text())
        onFileChanged: reload()
        // No file yet is the normal first run, and an empty list is exactly
        // right -- nothing is seeded, because there are no custom profiles
        // until the user makes one.
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.list = [];
                root.loaded = true;
            }
        }
    }
}
