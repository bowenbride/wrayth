pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.config

// The active colour profile. Reads ~/.config/wrayth/profile, watches it for
// changes, and exposes the resolved palette as flat tokens. Everything coloured
// in the shell binds to these, so a profile change recolours live.
Singleton {
    id: root

    // The profile written to disk. Falls back to Circuit if the file is missing
    // or holds a name we don't recognise.
    property string activeProfile: "Circuit"

    // **What the file asked for, whether or not it resolved yet.**
    // `profile` and `custom-profiles.json` are two FileViews loading
    // asynchronously and independently, and the profile file usually wins --
    // so a custom profile's name arrives before the palette that gives it
    // meaning. Resolving once and giving up is what silently put every
    // restart on a custom profile back onto Circuit.
    property string requested: ""
    // The last name warned about, so a retry loop does not warn on every pass.
    property string warnedAbout: ""

    // Set by the profile picker while previewing. Empty means "no preview".
    property string previewProfile: ""

    // What the shell is actually painted with right now.
    readonly property string profile: previewProfile || activeProfile

    // **Never undefined.** A profile can stop existing under the shell's feet
    // -- a hand edit of `custom-profiles.json`, a delete racing a repaint --
    // and every token below is bound to this. Without the fallback the whole
    // shell re-evaluated its colours against `undefined` once a frame:
    // measured at 513 TypeErrors in a few seconds, from the picker's
    // miniatures alone.
    readonly property var palette: Profiles.palettes[profile] ?? Profiles.presets.Circuit
    readonly property string description: Profiles.descriptions[profile] ?? ""
    readonly property url wallpaper: Paths.url(Paths.wallpaperFor(profile))

    // --- Tokens -------------------------------------------------------------
    // Backgrounds
    readonly property color ground: palette.ground
    readonly property color deep: palette.deep
    readonly property color panelHex: palette.panelHex
    readonly property color panel: palette.panel
    readonly property color panel2: palette.panel2
    readonly property color barBg: palette.barBg

    // Structure
    readonly property color hair: palette.hair
    readonly property color track: palette.track
    readonly property color cell: palette.cell

    // Type
    readonly property color text: palette.text
    readonly property color bright: palette.bright
    readonly property color dim: palette.dim
    readonly property color mute: palette.mute

    // Meaning
    readonly property color signal: palette.signal
    readonly property color accent: palette.accent
    readonly property color alert: palette.alert

    // --- Helpers ------------------------------------------------------------
    // Token at partial alpha, e.g. accent@15% row tints.
    function alpha(colour: color, a: real): color {
        return Qt.rgba(colour.r, colour.g, colour.b, a);
    }

    // Two tokens mixed to an **opaque** colour. `alpha` is the usual way to
    // tint, but a translucent fill over a wallpaper lets the image through the
    // label on top of it -- so anything sitting on an image blends instead.
    function blend(a: color, b: color, t: real): color {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1);
    }

    // The accent of a profile that isn't the active one (profile picker cards).
    function accentOf(name: string): color {
        const p = Profiles.palettes[name];
        return p ? p.accent : accent;
    }

    // The dark ink that goes on `accentOf(name)`: that profile's own ground,
    // not the shell's. A `CARD` tag in Redline's accent wants Redline's black
    // under it, which is not the black the picker happens to be wearing.
    function groundOf(name: string): color {
        const p = Profiles.palettes[name];
        return p ? p.ground : ground;
    }

    function wallpaperOf(name: string): url {
        return Paths.url(Paths.wallpaperFor(name));
    }

    // --- Persistence --------------------------------------------------------
    // Write a new profile to disk. The FileView below picks the change back up,
    // so activeProfile updates through the same path as an external edit.
    function apply(name: string): bool {
        const resolved = Profiles.resolve(name);
        if (!resolved)
            return false;
        previewProfile = "";
        // `requested` moves with it, now rather than when the file watcher
        // reloads. In that gap a stale `requested` was re-resolved against a
        // customs list that had just lost it, and warned about a profile the
        // shell had already moved off -- deleting a custom profile right after
        // switching away from it was enough.
        root.requested = resolved;
        profileFile.setText(`${resolved}\n`);
        activeProfile = resolved;
        return true;
    }

    function preview(name: string): bool {
        const resolved = Profiles.resolve(name);
        if (!resolved)
            return false;
        previewProfile = resolved;
        return true;
    }

    function clearPreview(): void {
        previewProfile = "";
    }

    // Whenever the profile changes -- picker, launcher, or a hand edit of the
    // file -- the helper script brings kitty and Hyprland along. `-n` stops it
    // rewriting the file the shell has just read, which would come straight
    // back as another change.
    // The command is set here rather than bound: a binding on `command` has not
    // necessarily re-evaluated by the time this handler runs, and the script
    // was being called with the profile before last.
    // **A second sync while the first is running is remembered, not dropped.**
    // `Process.running = true` on a process that is already running is a
    // no-op, so two profile changes inside the script's own runtime left
    // kitty and the Hyprland borders on the first of them while the shell
    // wore the second. It could not be reproduced from a session -- the
    // FileView coalesces and the script is quick -- but the mechanism is
    // plain, and "the colours are one profile behind and nobody can say why"
    // is exactly the shape of bug that survives a QA pass.
    property bool syncPending: false

    function syncExternal(): void {
        if (syncProc.running) {
            root.syncPending = true;
            return;
        }
        root.syncPending = false;
        syncProc.command = [Paths.profileScript, "-n", activeProfile];
        syncProc.running = true;
    }

    onActiveProfileChanged: syncExternal()

    Process {
        id: syncProc

        // `running` falling covers a clean exit and a script that could not
        // be started at all, which emits nothing else.
        onRunningChanged: if (!running && root.syncPending) root.syncExternal()
    }

    // A fresh start loads the profile it already had, so nothing changes and
    // nothing syncs -- yet the borders are still Caelestia's until ours are
    // set. Sync once on the way up. This also (re)makes the deck terminal's
    // emblem, so a missing one is made at every start; wrayth-emblem renames
    // it into place, so the deck terminal printing its greeting at the same
    // moment never reads a half-written file.
    Timer {
        interval: 1200
        running: true
        onTriggered: root.syncExternal()
    }

    // A Hyprland reload re-reads Caelestia's config, which puts its own border
    // colours back. Ours go on again afterwards.
    Connections {
        target: Hyprland

        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "configreloaded")
                root.syncExternal();
        }
    }

    FileView {
        id: profileFile

        path: Paths.profileFile
        watchChanges: true
        printErrors: false

        onLoaded: root.adopt(text())
        onFileChanged: reload()
        // No file yet: seed it with the default so the picker has something to
        // write over, and so the file is hand-editable from the start.
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                setText(`${root.activeProfile}\n`);
        }
    }

    function adopt(contents: string): void {
        root.requested = String(contents).trim();
        root.resolveRequested();
    }

    // Run on every read of the file **and** whenever the custom profiles
    // change, because either can be the half that was missing.
    function resolveRequested(): void {
        const resolved = Profiles.resolve(root.requested);
        if (resolved) {
            activeProfile = resolved;
            return;
        }
        // Still waiting on custom-profiles.json: an unknown name here is
        // expected and will be tried again the moment the customs land.
        if (!Customs.loaded)
            return;
        if (root.requested && root.warnedAbout !== root.requested) {
            root.warnedAbout = root.requested;
            console.warn(`wrayth: unknown profile ${JSON.stringify(root.requested)}, keeping ${activeProfile}`);
        }
        // The profile being *worn* has stopped existing as well -- the active
        // custom was deleted from the file. Something has to be painted, and
        // Circuit is the balanced default. The file is deliberately left
        // alone: a hand edit that broke it is the user's to fix, and
        // rewriting it would throw away what they typed.
        if (!Profiles.resolve(activeProfile))
            activeProfile = "Circuit";
    }

    Connections {
        target: Customs

        function onListChanged(): void {
            root.resolveRequested();
        }

        function onLoadedChanged(): void {
            root.resolveRequested();
        }
    }
}
