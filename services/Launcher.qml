pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// The launcher's matching and results. Desktop entries and the six colour
// profiles share one list; a profile entry applies itself rather than exec'ing.
Singleton {
    id: root

    readonly property int maxResults: 8

    property string query: ""
    property int selected: 0

    // How often each desktop entry has been launched, keyed by id. Kept in a
    // file so the order survives a restart; an empty search sorts by it.
    property var launches: ({})

    // Freedesktop categories are long and plural. The spec wants one short word.
    readonly property var categoryTags: ({
        TerminalEmulator: "TERMINAL",
        TextEditor: "EDITOR",
        IDE: "EDITOR",
        Development: "DEV",
        Security: "SECURITY",
        WebBrowser: "BROWSER",
        Network: "NET",
        AudioVideo: "MEDIA",
        Audio: "MEDIA",
        Video: "MEDIA",
        Game: "GAME",
        Graphics: "GFX",
        Office: "OFFICE",
        Settings: "SYSTEM",
        System: "SYSTEM",
        Utility: "UTIL"
    })

    function tagFor(entry: var): string {
        const categories = entry?.categories ?? [];
        for (const key of Object.keys(categoryTags)) {
            if (categories.indexOf(key) >= 0)
                return categoryTags[key];
        }
        return "APP";
    }

    // Subsequence match: every character of the needle appears in order. `bp`
    // finds both Burp Suite and btop, which is the spec's example. The score
    // rewards early and contiguous hits so the obvious answer sorts first.
    function score(text: string, needle: string): int {
        if (!needle)
            return 0;
        const haystack = text.toLowerCase();
        const want = needle.toLowerCase();
        let at = 0;
        let points = 0;
        let previous = -2;
        for (const character of want) {
            const found = haystack.indexOf(character, at);
            if (found < 0)
                return -1;
            points += found === previous + 1 ? 12 : 0;
            points += found === 0 ? 20 : Math.max(0, 10 - found);
            previous = found;
            at = found + 1;
        }
        return points;
    }

    // --- The app index ----------------------------------------------------------
    // **Plain data, built once the desktop entries settle, a few at a time.**
    // Searching `DesktopEntries` directly re-read every entry's properties
    // through JS and re-sorted them each time the list changed -- 33 times at
    // login as the entries arrived, 12 to 22 ms each on the main thread, and
    // again with the launcher closed whenever an app was installed. Now a
    // change schedules one rebuild, done in pieces of 25 entries so no piece
    // blocks a frame, and the search runs over lowercased copies.
    property var _apps: []
    property var _pending: []
    property var _source: []
    property int _at: 0
    Connections {
        target: DesktopEntries.applications
        function onValuesChanged(): void {
            rebuild.restart();
        }
    }
    Timer {
        id: rebuild

        interval: 300
        running: true
        onTriggered: {
            root._source = Array.from(DesktopEntries.applications?.values ?? []);
            root._pending = [];
            root._at = 0;
            chunk.restart();
        }
    }
    Timer {
        id: chunk

        interval: 1
        repeat: true
        onTriggered: {
            const end = Math.min(root._source.length, root._at + 25);
            for (let i = root._at; i < end; i++) {
                const entry = root._source[i];
                if (!entry || entry.noDisplay)
                    continue;
                const name = entry.name ?? "";
                const id = entry.id ?? "";
                root._pending.push({ name: name, id: id, lname: name.toLowerCase(), lid: id.toLowerCase(), tag: root.tagFor(entry), entry: entry });
            }
            root._at = end;
            if (end >= root._source.length) {
                stop();
                root._apps = root._pending;
                root._pending = [];
                root._source = [];
            }
        }
    }

    // `score` on text already lowercased.
    function scoreLower(haystack: string, want: string): int {
        if (!want)
            return 0;
        let at = 0;
        let points = 0;
        let previous = -2;
        for (const character of want) {
            const found = haystack.indexOf(character, at);
            if (found < 0)
                return -1;
            points += found === previous + 1 ? 12 : 0;
            points += found === 0 ? 20 : Math.max(0, 10 - found);
            previous = found;
            at = found + 1;
        }
        return points;
    }

    readonly property var shellViews: [
        { name: "KEYBINDS", open: "keybinds", words: ["keybinds", "keys", "shortcuts", "hotkeys"] },
        { name: "CLIPBOARD", open: "clipboard", words: ["clipboard", "paste", "history"] },
        { name: "RECORD", open: "record", words: ["record", "recording", "screen recorder", "capture video"] }
    ]

    readonly property var results: {
        const needle = query.trim();
        const found = [];

        const want = needle.toLowerCase();
        for (const app of root._apps) {
            const points = Math.max(scoreLower(app.lname, want), scoreLower(app.lid, want));
            if (points < 0)
                continue;
            found.push({
                kind: "app",
                name: app.name,
                tag: app.tag,
                points: points,
                uses: launches[app.id] ?? 0,
                entry: app.entry
            });
        }

        // Profiles join the list when the query looks like one, or like the
        // word itself -- an empty query leaves them out so apps get the room.
        if (needle) {
            for (const name of Profiles.names) {
                const points = Math.max(score(name, needle), score("profile", needle));
                if (points < 0)
                    continue;
                found.push({
                    kind: "profile",
                    name: `PROFILE ${name.toUpperCase()}`,
                    tag: "PROFILE",
                    points: points + 4,
                    uses: 0,
                    profile: name
                });
            }
        }

        // The shell's own views, by name or by what people call them.
        if (needle) {
            for (const view of root.shellViews) {
                const points = Math.max(...view.words.map(w => score(w, needle)));
                if (points < 0)
                    continue;
                found.push({
                    kind: "shell",
                    name: view.name,
                    tag: "SHELL",
                    points: points + 4,
                    uses: 0,
                    view: view.open
                });
            }
        }

        // With no query every score is 0, so the order is the launch count --
        // most used first, alphabetical among apps never launched. With a query
        // the match score leads and the count only breaks ties.
        found.sort((a, b) => b.points - a.points || b.uses - a.uses || a.name.localeCompare(b.name));
        return found.slice(0, maxResults);
    }

    readonly property int count: results.length

    function move(delta: int): void {
        if (count === 0)
            return;
        selected = (selected + delta + count) % count;
    }

    function activate(): void {
        const chosen = results[selected];
        if (!chosen)
            return;
        if (chosen.kind === "shell") {
            // Straight to the view: opening it closes the launcher.
            ShellState.openExclusive(chosen.view);
            return;
        }
        if (chosen.kind === "profile") {
            Theme.apply(chosen.profile);
        } else {
            record(chosen.entry.id);
            // Out of the deck first, or the app opens inside it.
            Deck.leave();
            // `execute()` runs the command as it stands and ignores
            // `Terminal=true`, so a terminal app (btop, htop, nmtui...) ran with
            // nowhere to draw and exited unseen. Those open in kitty, the
            // shell's own terminal.
            if (chosen.entry.runInTerminal)
                Quickshell.execDetached({
                    command: ["kitty", "-e"].concat(Array.from(chosen.entry.command)),
                    workingDirectory: chosen.entry.workingDirectory || Quickshell.env("HOME")
                });
            else
                chosen.entry.execute();
        }
        close();
    }

    function record(id: string): void {
        if (!id)
            return;
        const next = Object.assign({}, launches);
        next[id] = (next[id] ?? 0) + 1;
        launches = next;
        save();
    }

    function save(): void {
        let out = "";
        for (const id of Object.keys(launches))
            out += `${id} ${launches[id]}\n`;
        file.setText(out);
    }

    function open(): void {
        query = "";
        selected = 0;
        ShellState.openExclusive("launcher");
    }

    FileView {
        id: file

        path: Paths.launchesFile
        printErrors: false

        onLoaded: {
            const counts = {};
            for (const line of text().split("\n")) {
                const at = line.lastIndexOf(" ");
                if (at <= 0)
                    continue;
                const n = parseInt(line.slice(at + 1));
                if (isFinite(n))
                    counts[line.slice(0, at)] = n;
            }
            root.launches = counts;
        }
    }

    function close(): void {
        ShellState.closeAll();
    }

    onQueryChanged: selected = 0
}
