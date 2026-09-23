pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.utils
import qs.services

// The daily gigs file: parsing, the tickboxes' writes, and the midnight reset.
// The file stays hand-editable, so its own order is preserved on write and only
// the display sinks finished tasks to the bottom.
Singleton {
    id: root

    // { done: bool, name: string, tag: string }
    property var tasks: []

    // **What the shell draws, which is not always what is on disk.** Demo
    // mode substitutes the whole list rather than masking the names, because
    // the list's shape -- how many gigs, how many done, what the tags say --
    // is most of what a planner tells you about somebody. Everything below
    // reads `shown`; `_serialise` still reads `tasks`, so nothing masked can
    // reach the file.
    readonly property var shown: Demo.active ? Demo.tasks : tasks

    readonly property int total: shown.length
    readonly property int done: shown.filter(task => task.done).length

    // The "# date: YYYY-MM-DD" header the midnight reset works from.
    property string resetDate: ""

    // True while the panel's inline editor is up. The deck normally leaves the
    // keyboard to its terminal; this is what lets it take the keyboard while a
    // gig is actually being typed, and hand it straight back afterwards.
    property bool editing: false

    // The panel's order: outstanding tasks in file order, then the finished ones
    // sunk to the bottom. Each entry keeps the index it has in the file, which
    // is what a tickbox toggles.
    readonly property var ordered: {
        const pending = [];
        const finished = [];
        shown.forEach((task, index) => {
            const entry = {
                index: index,
                name: task.name,
                label: task.name,
                tag: task.tag,
                done: task.done,
                status: "DONE"
            };
            (task.done ? finished : pending).push(entry);
        });
        pending.forEach((entry, i) => {
            entry.status = i === 0 ? "ACTIVE" : (i === 1 ? "NEXT" : "QUEUED");
        });
        return pending.concat(finished);
    }

    // **A new planner is empty.** It used to be seeded with the maintainer's
    // own gigs, which then showed up on every fresh install; the panel now
    // shows a short hint on how to add one instead.
    readonly property string initialContents: `# date: ${_today()}
`

    function _today(): string {
        const now = new Date();
        return `${now.getFullYear()}-${Fmt.pad2(now.getMonth() + 1)}-${Fmt.pad2(now.getDate())}`;
    }

    function toggle(index: int): void {
        // **Nothing is written while the shell is being recorded.** The list
        // on screen is not the list on disk, so an index from one would land
        // on the wrong row of the other.
        if (Demo.active)
            return;
        if (index < 0 || index >= tasks.length)
            return;
        const next = tasks.slice();
        next[index] = {
            done: !next[index].done,
            name: next[index].name,
            tag: next[index].tag
        };
        tasks = next;
        _save();
    }

    // --- Editing, from the panel's inline editor -----------------------------
    // All of these refuse while recording, for the same reason toggle does: the
    // list on screen is the masked one, and an index from it is meaningless on
    // disk. A category is uppercased and capped at eight characters, wherever
    // it enters.
    function _normTag(tag: string): string {
        return (tag || "").trim().toUpperCase().slice(0, 8);
    }

    function _commit(next: var): void {
        tasks = next;
        _save();
    }

    // Add a gig at the end. An empty name is dropped rather than written.
    function append(name: string, tag: string): void {
        if (Demo.active)
            return;
        const clean = (name || "").trim();
        if (clean === "")
            return;
        _commit(tasks.concat([{
            done: false,
            name: clean,
            tag: root._normTag(tag)
        }]));
    }

    // Rename / retag a gig. Emptying its name removes it.
    function update(index: int, name: string, tag: string): void {
        if (Demo.active)
            return;
        if (index < 0 || index >= tasks.length)
            return;
        const clean = (name || "").trim();
        if (clean === "") {
            root.remove(index);
            return;
        }
        const next = tasks.slice();
        next[index] = {
            done: next[index].done,
            name: clean,
            tag: root._normTag(tag)
        };
        _commit(next);
    }

    function remove(index: int): void {
        if (Demo.active)
            return;
        if (index < 0 || index >= tasks.length)
            return;
        const next = tasks.slice();
        next.splice(index, 1);
        _commit(next);
    }

    // Replace the whole list in a new order -- what a drag-reorder commits. The
    // panel hands back the displayed order, so the file's order becomes the
    // display's (finished gigs already sink to the bottom there, so the file
    // stays consistent with what the reset and the status logic expect).
    function setOrder(list: var): void {
        if (Demo.active)
            return;
        _commit(list.map(t => ({
            done: !!t.done,
            name: t.name,
            tag: root._normTag(t.tag)
        })));
    }

    function _serialise(): string {
        let out = `# date: ${resetDate || _today()}\n`;
        for (const task of tasks)
            out += `[${task.done ? "x" : " "}] ${task.name}${task.tag ? ` | ${task.tag}` : ""}\n`;
        return out;
    }

    function _save(): void {
        file.setText(_serialise());
    }

    // Everything unticks when the date on the file is no longer today. Checked
    // once a minute rather than scheduled for midnight, so a suspend across it
    // still gets caught on resume.
    function _resetIfStale(): void {
        const today = _today();
        if (resetDate === today || tasks.length === 0)
            return;
        resetDate = today;
        tasks = tasks.map(task => ({
            done: false,
            name: task.name,
            tag: task.tag
        }));
        _save();
    }

    function _parse(contents: string): void {
        const entries = [];
        for (const line of contents.split("\n")) {
            const header = line.match(/^#\s*date:\s*(\S+)/);
            if (header) {
                resetDate = header[1];
                continue;
            }
            const task = line.match(/^\[([ xX])\]\s*(.*)$/);
            if (!task)
                continue;
            const body = task[2];
            const split = body.lastIndexOf("|");
            entries.push({
                done: task[1].toLowerCase() === "x",
                name: (split >= 0 ? body.slice(0, split) : body).trim(),
                tag: split >= 0 ? body.slice(split + 1).trim() : ""
            });
        }
        tasks = entries;
        // After the load settles, so the write does not re-enter the parse.
        Qt.callLater(root._resetIfStale);
    }

    FileView {
        id: file

        path: Paths.plannerFile
        watchChanges: true
        printErrors: false

        onLoaded: root._parse(text())
        onFileChanged: reload()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                setText(root.initialContents);
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root._resetIfStale()
    }
}
