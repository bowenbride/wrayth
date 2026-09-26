pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services

// The binds Hyprland actually has, for the KEYBINDS overlay (Super + /), read
// from `hyprctl binds -j` each time the overlay opens -- never a list of our
// own that could go out of date.
//
// Wrayth's binds carry a description, `wrayth:<id>:<group>:<label>:<default
// keys>` (external/hypr-wrayth.lua), which is how they are told from yours.
// Moving one writes ~/.config/wrayth/keybinds.lua -- a table of id = "KEYS",
// read after the defaults, and never touched by updates -- and applies it at
// once through `wrayth_apply_keybinds()`. Binds from your own config are listed
// and marked FROM YOUR CONFIG, and are changed there, not here.
Singleton {
    id: root

    readonly property string file: `${Quickshell.env("HOME")}/.config/wrayth/keybinds.lua`
    readonly property var groups: ["SHELL", "WINDOWS", "WORKSPACES", "MEDIA AND CAPTURE"]

    // [{ id, group, label, keys, defaults, ours, changed }], in catalogue order
    // within each group.
    property var binds: []
    // Your changes: id -> keys ("" = no key).
    property var changes: ({})
    property bool busy: false
    property bool fileExists: false

    // Hyprland's modifier mask, in the order a key string names them.
    readonly property var mods: [[64, "SUPER"], [4, "CTRL"], [8, "ALT"], [1, "SHIFT"]]
    function keysOf(modmask: int, key: string): string {
        const names = mods.filter(m => modmask & m[0]).map(m => m[1]);
        return names.concat([key]).join(" + ");
    }
    // Keys as keycaps show them: `SUPER + slash` -> SUPER / slash.
    readonly property var capNames: ({
        slash: "/", SUPER_L: "TAP", Print: "PRINT", space: "SPACE", Return: "ENTER", Escape: "ESC",
        XF86AudioPlay: "PLAY", XF86AudioPause: "PAUSE", XF86AudioNext: "NEXT", XF86AudioPrev: "PREV",
        XF86AudioRaiseVolume: "VOL +", XF86AudioLowerVolume: "VOL -", XF86AudioMute: "MUTE",
        XF86MonBrightnessUp: "BRI +", XF86MonBrightnessDown: "BRI -",
        mouse_down: "SCROLL DOWN", mouse_up: "SCROLL UP", "mouse:272": "LEFT DRAG", "mouse:273": "RIGHT DRAG"
    })
    function capsOf(keys: string): var {
        return keys ? keys.split(" + ").map(k => root.capNames[k] ?? k.toUpperCase()) : [];
    }

    function groupFor(bind: var): string {
        const key = bind.key ?? "";
        if (/^XF86|^Print$/.test(key))
            return "MEDIA AND CAPTURE";
        if (/^[0-9]$/.test(key))
            return "WORKSPACES";
        return "WINDOWS";
    }

    function refresh(): void {
        if (lister.running)
            return;
        lister.running = true;
        reader.reload();
    }

    Process {
        id: lister

        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }

    function parse(text: string): void {
        let raw = [];
        try {
            raw = JSON.parse(text);
        } catch (e) {
            return;
        }
        const ours = [];
        const theirs = [];
        const seen = {};
        for (const b of raw) {
            if ((b.submap ?? "") !== "")
                continue;
            const keys = keysOf(b.modmask ?? 0, b.key || (b.mouse ? `mouse:${b.keycode}` : ""));
            const d = b.description ?? "";
            if (d.startsWith("wrayth:")) {
                // wrayth:<id>:<group>:<label>:<default keys> -- the keys are
                // the last field, so a label with a colon in it still reads.
                const parts = d.split(":");
                const id = parts[1], group = parts[2];
                const defaults = parts[parts.length - 1];
                const label = parts.slice(3, -1).join(":");
                if (seen[id])
                    continue;
                seen[id] = true;
                ours.push({ id: id, group: group, label: label, keys: keys, defaults: defaults, ours: true });
            } else if (d.startsWith("wrayth-fixed:")) {
                const [, group, label] = d.split(":");
                ours.push({ id: `fixed:${keys}`, group: group, label: label, keys: keys, defaults: keys, ours: false, fixed: true });
            } else {
                // Named by its own description when it has one (a Lua bind's
                // dispatcher is only "__lua", which says nothing).
                const named = d !== "" ? d : b.dispatcher && b.dispatcher !== "__lua" ? `${b.dispatcher} ${b.arg ?? ""}`.trim() : "A bind in your config";
                theirs.push({ id: `user:${keys}`, group: groupFor(b), label: named,
                    keys: keys, defaults: keys, ours: false });
            }
        }
        root.binds = ours.concat(theirs).map(b => Object.assign(b, { changed: b.ours && b.keys !== b.defaults }));
    }

    // --- keybinds.lua ---------------------------------------------------------
    FileView {
        id: reader

        path: root.file
        printErrors: false
        onLoaded: {
            root.fileExists = true;
            root.changes = root.readChanges(text());
        }
        onLoadFailed: {
            root.fileExists = false;
            root.changes = ({});
        }
    }

    function readChanges(text: string): var {
        const out = {};
        const re = /^\s*\[?"?([a-z0-9-]+)"?\]?\s*=\s*"([^"]*)"/gm;
        let m;
        while ((m = re.exec(text)) !== null)
            out[m[1]] = m[2];
        return out;
    }

    function writeChanges(next: var): void {
        const ids = Object.keys(next).sort();
        const body = ids.map(id => `    ["${id}"] = "${next[id].replace(/["\\\n]/g, "")}",`).join("\n");
        const text = `-- Your Wrayth keybinds: what you changed in KEYBINDS (Super + /).
--
-- Read after Wrayth's defaults (external/hypr-wrayth.lua), so these win, and
-- updates never touch this file. Each line is an action and its keys, written
-- the way Hyprland names them: "SUPER + SHIFT + E". "" leaves an action with
-- no key. Delete a line to put that action back on its default.
return {
${body}
}
`;
        root.changes = next;
        writer.setText(text);
        apply.restart();
    }

    FileView {
        id: writer

        path: root.file
        printErrors: false
    }

    // Applied at once: the catalogue re-reads this file and re-binds. If the
    // function is not there (a config that does not load hypr-wrayth.lua), a
    // config reload does the same.
    Timer {
        id: apply

        interval: 80
        onTriggered: {
            root.busy = true;
            applier.running = true;
        }
    }
    Process {
        id: applier

        command: ["sh", "-c", 'out=$(hyprctl eval "wrayth_apply_keybinds()" 2>&1); case "$out" in *rror*|*nil*) hyprctl reload >/dev/null ;; esac']
        onExited: {
            root.busy = false;
            root.refresh();
        }
    }

    // --- Changing a bind --------------------------------------------------------
    function bindFor(id: string): var {
        return binds.find(b => b.id === id) ?? null;
    }
    // What already uses these keys, other than `id` itself.
    function holderOf(keys: string, id: string): var {
        return binds.find(b => b.id !== id && b.keys === keys) ?? null;
    }

    function setKeys(id: string, keys: string): void {
        const bind = bindFor(id);
        if (!bind || !bind.ours)
            return;
        const next = Object.assign({}, changes);
        if (keys === bind.defaults)
            delete next[id];
        else
            next[id] = keys;
        writeChanges(next);
    }

    // Both Wrayth's: each takes the other's keys.
    function swap(id: string, keys: string): void {
        const bind = bindFor(id);
        const other = holderOf(keys, id);
        if (!bind || !other || !other.ours)
            return;
        const next = Object.assign({}, changes);
        const put = (b, k) => {
            if (k === b.defaults)
                delete next[b.id];
            else
                next[b.id] = k;
        };
        put(bind, keys);
        put(other, bind.keys);
        writeChanges(next);
    }

    function reset(id: string): void {
        const next = Object.assign({}, changes);
        delete next[id];
        writeChanges(next);
    }

    // Would this leave the lockscreen or the power menu with no key at all?
    function strands(id: string, keys: string): bool {
        return (id === "lock" || id === "power") && keys === "";
    }

    // --- The capture submap -----------------------------------------------------
    // Every bind is off while new keys are captured (the `wrayth-capture`
    // submap, whose only bind is Escape back out), so they reach the overlay.
    property bool capturing: false
    function beginCapture(): void {
        capturing = true;
        Hyprland.dispatch(`hl.dsp.submap("wrayth-capture")`);
        captureLimit.restart();
    }
    function endCapture(): void {
        if (!capturing)
            return;
        capturing = false;
        captureLimit.stop();
        Hyprland.dispatch(`hl.dsp.submap("reset")`);
    }
    // Never left in the submap: a capture nobody finishes ends on its own.
    Timer {
        id: captureLimit
        interval: 15000
        onTriggered: root.endCapture()
    }

    // Opens keybinds.lua in the terminal editor ($EDITOR, else nano), making
    // it first if it is not there.
    function openFile(): void {
        if (!fileExists)
            writeChanges(changes);
        ShellState.openExclusive("");
        Deck.launch(["sh", "-c", 'exec kitty -e "${EDITOR:-nano}" "$1"', "sh", file]);
    }
}
