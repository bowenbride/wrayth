pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services

// The clipboard history (Super + Shift + V). `wl-paste --watch` runs
// external/wrayth-clip on every new selection; it prints one line, and the
// entry is kept here.
//
// **Privacy, from the PRIVACY page (privacy.json):**
//   HISTORY  "memory" (the default): kept in this process's memory only,
//            never written anywhere, gone at logout;
//            "disk": also saved, owner-only (0600), in
//            ~/.local/state/wrayth/clipboard.json;
//            "off": nothing is watched, nothing is kept.
//   ON LOCK  "keep", or "clear": locking empties it (and the file).
// Anything a password manager marks as sensitive is never read at all (see
// wrayth-clip).
//
// Limits: 100 entries (pinned ones kept first, at most 20 of them), text up
// to 1 MiB, images up to 5 MiB and at most 20 images.
Singleton {
    id: root

    readonly property int limit: 100
    readonly property int pinLimit: 20
    readonly property int imageLimit: 20

    // --- Settings ------------------------------------------------------------
    property string history: "memory"   // "memory" | "disk" | "off"
    property string onLock: "keep"      // "keep" | "clear"
    readonly property string settingsFile: `${Quickshell.env("HOME")}/.config/wrayth/privacy.json`
    readonly property string diskFile: `${Quickshell.env("HOME")}/.local/state/wrayth/clipboard.json`

    // **Where images are kept: files, never strings.** An image entry's `data`
    // is the path of its bytes in the store (older base64 entries still work).
    // MEMORY ONLY keeps them in the runtime directory -- RAM, owner-only,
    // emptied at logout -- and SAVE TO DISK under ~/.local/state/wrayth.
    readonly property string memoryStore: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/wrayth/clip`
    readonly property string diskStore: `${Quickshell.env("HOME")}/.local/state/wrayth/clipboard-images`
    readonly property string store: history === "disk" ? diskStore : memoryStore
    // **MEMORY ONLY lasts until logout, not until the next reload.** The list
    // itself is kept in the runtime directory too (owner-only, in RAM, emptied
    // at logout, never on disk), so a shell reload or an update no longer
    // empties it. SAVE TO DISK keeps it under ~/.local/state/wrayth as before.
    readonly property string memoryFile: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/wrayth/clipboard.json`
    readonly property string historyFile: history === "disk" ? diskFile : memoryFile
    property bool historyRead: false
    function isFile(e: var): bool {
        return e.kind === "image" && typeof e.data === "string" && e.data.startsWith("/");
    }

    function setHistory(mode: string): void {
        if (["memory", "disk", "off"].indexOf(mode) < 0 || mode === history)
            return;
        const from = store;
        history = mode;
        if (mode === "off")
            entries = [];
        // The images follow the mode to their new store.
        if (store !== from) {
            entries = entries.map(e => isFile(e) && e.data.startsWith(`${from}/`) ? Object.assign({}, e, { data: `${store}/${e.data.slice(from.length + 1)}` }) : e);
            mover.command = ["sh", "-c", 'umask 077; mkdir -p "$2" || exit 0; for f in "$1"/*; do [ -f "$f" ] && mv -f -- "$f" "$2"/; done; [ "$3" = disk ] || rmdir -- "$1" 2> /dev/null; true', "sh", from, store, mode];
            mover.running = true;
        }
        // Leaving a mode takes its file away with it; the new one is written.
        removeFiles([diskFile, memoryFile].filter(f => f !== historyFile || mode === "off"));
        if (mode !== "off")
            saveToDisk();
        saveSettings();
        watcher.running = false; // restarted by `revive`, on the new store
        sweepLater.restart();
    }
    function setOnLock(mode: string): void {
        if (["keep", "clear"].indexOf(mode) < 0)
            return;
        onLock = mode;
        saveSettings();
    }

    FileView {
        id: settings

        path: root.settingsFile
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                if (["memory", "disk", "off"].indexOf(s.history) >= 0)
                    root.history = s.history;
                if (["keep", "clear"].indexOf(s.onLock) >= 0)
                    root.onLock = s.onLock;
            } catch (e) {
                // Never saved over (as effects.json and wallpapers.json): a hand
                // edit with a typo is not replaced by defaults on the next change.
                root.settingsDamaged = true;
                console.warn(`wrayth: privacy.json is not readable JSON (${e}); using the defaults, and not saving over it`);
            }
            root.settingsRead = true;
            if (root.history === "off")
                root.historyRead = true;
            else
                disk.reload();
        }
        onLoadFailed: {
            root.settingsRead = true;
            disk.reload();
        }
    }
    property bool settingsRead: false
    property bool settingsDamaged: false

    function saveSettings(): void {
        if (settingsDamaged)
            return;
        settings.setText(`${JSON.stringify({ history: root.history, onLock: root.onLock }, null, 2)}\n`);
    }

    // --- The entries -------------------------------------------------------------
    // { key, kind: "text" | "image", mime, data (base64), preview, bytes, time, pinned }
    Process {
        id: mover
    }

    // Image files nothing refers to any more (dropped, deleted, cleared, or
    // left by an earlier run in MEMORY ONLY) are removed, a moment after the
    // list settles.
    Timer {
        id: sweepLater

        interval: 1500
        onTriggered: {
            const keep = root.entries.filter(e => root.isFile(e) && e.data.startsWith(`${root.store}/`)).map(e => e.data.slice(root.store.length + 1));
            sweeper.command = ["sh", "-c", 'cd "$1" 2> /dev/null || exit 0; shift; for f in *; do [ -f "$f" ] || continue; case " $* " in *" $f "*) ;; *) rm -f -- "$f" ;; esac; done', "sh", root.store].concat(keep);
            sweeper.running = true;
        }
    }
    Process {
        id: sweeper
    }
    onEntriesChanged: if (historyRead) sweepLater.restart()

    property var entries: []
    property int _next: 1
    readonly property var ordered: entries.filter(e => e.pinned).concat(entries.filter(e => !e.pinned))

    // Base64 to text, decoded as UTF-8 (the preview only; the entry itself
    // stays base64, byte for byte what was copied).
    readonly property string b64chars: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    function textOf(b64: string, maxBytes: int): string {
        const bytes = [];
        let buffer = 0, bits = 0;
        for (let i = 0; i < b64.length && bytes.length < maxBytes; i++) {
            const v = b64chars.indexOf(b64[i]);
            if (v < 0)
                continue;
            buffer = (buffer << 6) | v;
            bits += 6;
            if (bits >= 8) {
                bits -= 8;
                bytes.push((buffer >> bits) & 0xff);
            }
        }
        let out = "";
        for (let i = 0; i < bytes.length;) {
            const c = bytes[i];
            let cp = 0xfffd, n = 1;
            if (c < 0x80)
                cp = c;
            else if (c >= 0xc0 && c < 0xe0 && i + 1 < bytes.length)
                cp = ((c & 0x1f) << 6) | (bytes[i + 1] & 0x3f), n = 2;
            else if (c >= 0xe0 && c < 0xf0 && i + 2 < bytes.length)
                cp = ((c & 0x0f) << 12) | ((bytes[i + 1] & 0x3f) << 6) | (bytes[i + 2] & 0x3f), n = 3;
            else if (c >= 0xf0 && i + 3 < bytes.length)
                cp = ((c & 0x07) << 18) | ((bytes[i + 1] & 0x3f) << 12) | ((bytes[i + 2] & 0x3f) << 6) | (bytes[i + 3] & 0x3f), n = 4;
            out += String.fromCodePoint(cp);
            i += n;
        }
        return out;
    }

    function add(kind: string, mime: string, data: string, bytes: int): void {
        // A copy of something already here (the shell pasting it back, or the
        // same thing copied twice) moves it to the top instead.
        const same = entries.find(e => e.kind === kind && e.data === data);
        if (same) {
            entries = [Object.assign({}, same, { time: Date.now() })].concat(entries.filter(e => e !== same));
            persist();
            return;
        }
        const entry = {
            key: root._next++,
            kind: kind,
            mime: mime,
            data: data,
            preview: kind === "text" ? textOf(data, 1600).slice(0, 400) : "",
            bytes: bytes,
            time: Date.now(),
            pinned: false
        };
        let next = [entry].concat(entries);
        // Images beyond their own cap, then everything beyond the total,
        // oldest unpinned first.
        const images = next.filter(e => e.kind === "image" && !e.pinned);
        if (images.length > imageLimit)
            next = next.filter(e => images.slice(imageLimit).indexOf(e) < 0);
        const unpinned = next.filter(e => !e.pinned);
        const room = limit - next.filter(e => e.pinned).length;
        if (unpinned.length > room)
            next = next.filter(e => e.pinned || unpinned.slice(0, room).indexOf(e) >= 0);
        entries = next;
        persist();
    }

    function remove(key: int): void {
        entries = entries.filter(e => e.key !== key);
        persist();
    }
    function togglePin(key: int): void {
        const e = entries.find(x => x.key === key);
        if (!e)
            return;
        if (!e.pinned && entries.filter(x => x.pinned).length >= pinLimit)
            return;
        entries = entries.map(x => x.key === key ? Object.assign({}, x, { pinned: !x.pinned }) : x);
        persist();
    }
    function clear(): void {
        entries = [];
        persist();
    }

    // --- Watching ---------------------------------------------------------------
    readonly property bool watching: settingsRead && history !== "off"
    Process {
        id: watcher

        running: root.watching
        command: ["wl-paste", "--watch", Quickshell.shellPath("external/wrayth-clip"), root.store]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                const parts = line.split(" ");
                if (parts[0] === "TEXT" && parts.length === 3)
                    root.add("text", "text/plain;charset=utf-8", parts[2], Number(parts[1]));
                else if (parts[0] === "IMAGEFILE" && parts.length >= 4 && /^image\/(png|jpeg|webp)$/.test(parts[1]))
                    root.add("image", parts[1], parts.slice(3).join(" "), Number(parts[2]));
                else if (parts[0] === "IMAGE" && parts.length === 4 && /^image\/(png|jpeg|webp)$/.test(parts[1]))
                    root.add("image", parts[1], parts[3], Number(parts[2]));
                else if (parts[0] === "SKIP")
                    root.lastSkip = parts[1] ?? "";
            }
        }
        // wl-paste exiting (the compositor restarting, say) is not the end.
        onRunningChanged: if (!running && root.watching) revive.restart()
    }
    Timer {
        id: revive
        interval: 3000
        onTriggered: if (root.watching) watcher.running = true
    }
    // Why the last selection was not kept: for the tests.
    property string lastSkip: ""

    // --- ON LOCK ------------------------------------------------------------------
    Connections {
        target: ShellState
        function onLockedChanged(): void {
            if (ShellState.locked && root.onLock === "clear")
                root.clear();
        }
    }

    // --- SAVE TO DISK ---------------------------------------------------------------
    FileView {
        id: disk

        path: root.historyFile
        printErrors: false
        blockLoading: false
        onLoaded: {
            root.historyRead = true;
            if (root.history === "off")
                return;
            try {
                const saved = JSON.parse(text());
                const kept = (saved.entries ?? []).map(e => Object.assign(e, { key: root._next++ }));
                // Anything copied while this was loading stays on top.
                root.entries = root.entries.concat(kept.filter(k => !root.entries.some(e => e.kind === k.kind && e.data === k.data)));
            } catch (e) {
                console.warn(`wrayth: clipboard history is not readable JSON (${e})`);
            }
        }
        onLoadFailed: root.historyRead = true
    }
    function persist(): void {
        if (history !== "off" && historyRead)
            saveToDisk();
    }
    function saveToDisk(): void {
        writer.running = false;
        writer.payload = JSON.stringify({ entries: entries.map(e => ({ kind: e.kind, mime: e.mime, data: e.data, preview: e.preview, bytes: e.bytes, time: e.time, pinned: e.pinned })) });
        writer.running = true;
    }
    // Written owner-only from the start (umask 077), through stdin.
    Process {
        id: writer

        property string payload: ""
        stdinEnabled: true
        command: ["sh", "-c", 'umask 077; mkdir -p "${1%/*}" && cat > "$1.tmp" && chmod 600 "$1.tmp" && mv "$1.tmp" "$1"', "sh", root.historyFile]
        onStarted: {
            write(payload);
            stdinEnabled = false;
        }
        onExited: stdinEnabled = true
    }
    function removeDiskFile(): void {
        removeFiles([diskFile]);
    }
    function removeFiles(paths: var): void {
        remover.command = ["rm", "-f", "--"].concat(paths);
        remover.running = true;
    }
    Process {
        id: remover
        command: ["rm", "-f", "--", root.diskFile]
    }

    // --- Putting one back, and pasting it -----------------------------------------
    // The content goes to wl-copy through stdin, never on a command line
    // (which any process can read).
    property string pasteInto: ""
    function use(key: int, paste: bool): void {
        const e = entries.find(x => x.key === key);
        if (!e)
            return;
        if (isFile(e)) {
            copier.payload = "";
            copier.command = ["sh", "-c", 'wl-copy --type "$1" < "$2"', "sh", e.mime, e.data];
        } else {
            copier.payload = e.data;
            copier.command = ["sh", "-c", 'base64 -d | wl-copy --type "$1"', "sh", e.mime];
        }
        copier.paste = paste;
        copier.running = true;
    }
    Process {
        id: copier

        property string payload: ""
        property bool paste: false
        stdinEnabled: true
        onStarted: {
            write(payload);
            stdinEnabled = false;
        }
        onExited: {
            stdinEnabled = true;
            if (paste)
                pasteLater.restart();
        }
    }
    // Once the overlay has gone and the window has the keyboard back: paste
    // into the window that was focused before the list opened -- Ctrl + V, or
    // Ctrl + Shift + V in a terminal, where Ctrl + V is a key of its own.
    readonly property var terminals: ["kitty", "wrayth-deck", "foot", "alacritty", "org.wezfurlong.wezterm", "com.mitchellh.ghostty", "konsole", "org.gnome.console", "gnome-terminal-server", "xterm", "st", "urxvt"]
    Timer {
        id: pasteLater
        interval: 120
        onTriggered: {
            const address = /^0x[0-9a-f]+$/.test(root.pasteInto) ? root.pasteInto : "";
            const terms = root.terminals.map(t => `["${t}"] = true`).join(", ");
            Hyprland.dispatch(`(function() local terms = { ${terms} } for _, w in ipairs(hl.get_windows()) do if w.address == "${address}" then return hl.dsp.send_shortcut({ mods = terms[string.lower(w.class or "")] and "CTRL SHIFT" or "CTRL", key = "V", window = w }) end end return hl.dsp.no_op() end)()`);
        }
    }

    Component.onCompleted: settings.reload()
}
