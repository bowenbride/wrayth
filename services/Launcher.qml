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

    readonly property var results: {
        const needle = query.trim();
        const found = [];

        for (const entry of DesktopEntries.applications?.values ?? []) {
            if (entry.noDisplay)
                continue;
            const points = Math.max(score(entry.name, needle), score(entry.id ?? "", needle));
            if (points < 0)
                continue;
            found.push({
                kind: "app",
                name: entry.name,
                tag: tagFor(entry),
                points: points,
                uses: launches[entry.id] ?? 0,
                entry: entry
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
                    name: `PROFILE${Appearance.separator}${name.toUpperCase()}`,
                    tag: "PROFILE",
                    points: points + 4,
                    uses: 0,
                    profile: name
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
