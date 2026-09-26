pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Keyboard layouts and input methods, for the bar's INPUT readout and dropdown.
//
// Two sources, both read without polling:
//  - Hyprland's layouts for the main keyboard (`hyprctl devices -j`), read at
//    start and again on its `activelayout` and `configreloaded` events.
//  - fcitx5, when it is running: `fcitx5-remote` for its state and current
//    input method, read at start, when we switch, and when the focused window
//    changes (the moment a person switching inside fcitx5 would look).
//
// `modes` is [{ id, kind: "layout"|"im", name, code, glyph }]. The readout is
// shown only when there are two or more of them. `simulate` replaces the
// real backend for tests -- nothing then touches the keyboard.
Singleton {
    id: root

    property var layouts: []        // [{ code, name }]
    property int layoutIndex: 0
    property string keyboard: ""
    property bool fcitx: false
    property bool fcitxActive: false
    property string fcitxIm: ""

    // Tests: a list of modes to show instead of the real ones, and which is
    // current. Empty: the real backend.
    property var simulated: []
    property int simulatedIndex: 0
    readonly property bool simulating: simulated.length > 0

    readonly property var modes: {
        if (simulating)
            return simulated;
        const out = layouts.map((l, i) => ({ id: `layout:${i}`, kind: "layout", name: l.name, code: l.code, glyph: codeGlyph(l.code) }));
        if (fcitx && fcitxIm !== "" && !/^keyboard-/.test(fcitxIm))
            out.push({ id: "im", kind: "im", name: imName(fcitxIm), code: fcitxIm, glyph: imGlyph(fcitxIm) });
        return out;
    }
    readonly property int current: {
        if (simulating)
            return Math.max(0, Math.min(simulatedIndex, simulated.length - 1));
        if (fcitx && fcitxActive && modes.length > layouts.length)
            return modes.length - 1;
        return Math.max(0, Math.min(layoutIndex, layouts.length - 1));
    }
    readonly property bool shown: modes.length >= 2
    readonly property string glyph: modes[current]?.glyph ?? ""

    // EN, あ, ア, or the layout's own code.
    function codeGlyph(code: string): string {
        const c = (code || "").toLowerCase();
        if (c === "us" || c === "gb" || c === "en")
            return "EN";
        return c.toUpperCase().slice(0, 3);
    }
    function imGlyph(im: string): string {
        const s = im.toLowerCase();
        if (s.includes("katakana"))
            return "ア";
        if (/mozc|anthy|kkc|skk|hiragana|japanese/.test(s))
            return "あ";
        return s.replace(/^keyboard-/, "").toUpperCase().slice(0, 3);
    }
    function imName(im: string): string {
        const s = im.toLowerCase();
        if (s.includes("katakana"))
            return "JAPANESE // KATAKANA";
        if (/mozc|anthy|kkc|skk|hiragana|japanese/.test(s))
            return "JAPANESE // HIRAGANA";
        return im.toUpperCase();
    }

    // --- Reading -----------------------------------------------------------
    function refresh(): void {
        if (!devices.running)
            devices.running = true;
        if (!fcitxProbe.running)
            fcitxProbe.running = true;
    }
    Component.onCompleted: refresh()

    Process {
        id: devices

        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let d;
                try {
                    d = JSON.parse(text);
                } catch (e) {
                    return;
                }
                const kb = (d.keyboards ?? []).find(k => k.main) ?? (d.keyboards ?? [])[0];
                if (!kb)
                    return;
                root.keyboard = kb.name;
                const codes = (kb.layout || "").split(",").map(s => s.trim()).filter(s => s !== "");
                // Hyprland names only the active keymap; the others go by code.
                const active = kb.active_layout_index ?? Math.max(0, codes.length > 1 ? -1 : 0);
                root.layouts = codes.map((c, i) => ({ code: c, name: i === active ? (kb.active_keymap || c).toUpperCase() : c.toUpperCase() }));
                root.layoutIndex = active >= 0 ? active : 0;
            }
        }
    }

    // fcitx5-remote prints 0 (not running), 1 (inactive) or 2 (active).
    Process {
        id: fcitxProbe

        command: ["sh", "-c", 'command -v fcitx5-remote >/dev/null && pgrep -x fcitx5 >/dev/null || exit 0; echo "$(fcitx5-remote) $(fcitx5-remote -n)"']
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim().split(/\s+/);
                root.fcitx = t.length >= 1 && t[0] !== "" && t[0] !== "0";
                root.fcitxActive = t[0] === "2";
                root.fcitxIm = root.fcitx ? (t[1] ?? "") : "";
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            const n = event.name;
            if (n === "activelayout" || n === "configreloaded")
                devices.running = true;
            else if (n === "activewindow" && root.fcitx)
                fcitxProbe.running = true;
        }
    }

    // --- Switching -----------------------------------------------------------
    // Super + Space: the next mode, wrapping.
    function next(): void {
        if (modes.length < 2)
            return;
        select((current + 1) % modes.length);
    }
    function select(i: int): void {
        if (simulating) {
            simulatedIndex = i;
            return;
        }
        const m = modes[i];
        if (!m)
            return;
        if (m.kind === "im") {
            switcher.exec(["fcitx5-remote", "-o"]);
        } else {
            const cmd = [`hyprctl switchxkblayout ${root.keyboard ? `'${root.keyboard}'` : "main"} ${i}`];
            if (fcitx)
                cmd.push("fcitx5-remote -c");
            switcher.exec(["sh", "-c", cmd.join("; ")]);
        }
    }
    Process {
        id: switcher
        onExited: root.refresh()
    }
}
