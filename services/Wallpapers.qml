pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// The wallpaper library, one pool per profile, and what the shell is showing
// right now.
//
// Everything is kept in ~/.config/wrayth/wallpapers.json as paths *relative
// to the library folder*, so moving the folder moves every pool with it and a
// pool never holds a path to somewhere the user no longer keeps pictures.
//
// Nothing here swaps an image directly. It publishes `displayed`, and
// `components/Wallpaper.qml` crossfades to whatever that becomes -- which is
// what makes "every wallpaper change crossfades" a property of the shell
// rather than a thing each caller remembers to do.
Singleton {
    id: root

    // --- Settings -----------------------------------------------------------
    // On, the wallpaper is part of the profile: applying one switches to its
    // wallpaper and previewing one shows it. Off, the wallpaper is the user's
    // and survives every profile change.
    property bool dynamic: true
    // The library folder. Empty means unset -- the picker's field is blank and
    // nothing can be added until it points somewhere.
    property string folder: ""
    // What was on screen when `dynamic` was switched off. Persisted, so a
    // restart does not quietly re-attach the wallpaper to the profile.
    property string lockedFile: ""

    // name -> { mode, every, fade, items: [{ file, on, star }] }
    property var pools: ({})

    readonly property string wraythFolder: Paths.wraythSubfolder(folder)

    // --- Pools --------------------------------------------------------------
    readonly property var modes: ["SINGLE", "CYCLE", "SHUFFLE"]

    function generatedName(name: string): string {
        // Spaces become hyphens and **every other non-`[a-z0-9-]` character is
        // dropped**, so a profile name can never build a path outside the
        // wallpaper folder (`../`, a `/`, a leading dot). Must match
        // Paths.wallpaperFor, which reads the file this writes.
        return `net-${name.toLowerCase().replace(/ /g, "-").replace(/[^a-z0-9-]/g, "")}.png`;
    }

    // A profile's own generated wallpaper, relative to the folder.
    function ownFile(name: string): string {
        return `wrayth/${root.generatedName(name)}`;
    }

    // **The bundled first-run wallpaper for a preset profile.** The six presets
    // each ship a pre-generated PNG inside the shell (assets/wallpapers/), so a
    // fresh install shows the right image before the user has picked a wallpaper
    // folder or generation has run. Returns "" for a custom profile -- those
    // render on the solid Theme.deep until they are generated.
    function presetAsset(name: string): url {
        if (Profiles.presetNames.indexOf(name) < 0)
            return "";
        return Paths.url(Quickshell.shellPath(`assets/wallpapers/${root.generatedName(name)}`));
    }

    // Every profile has a pool whether or not the file has one: the default is
    // its own wallpaper, ticked and starred, which is what the shell did before
    // pools existed.
    function poolFor(name: string): var {
        const stored = root.pools[name];
        if (stored)
            return stored;
        return {
            mode: "SINGLE",
            every: 15,
            fade: 1.5,
            items: [
                {
                    file: root.ownFile(name),
                    on: true,
                    star: true
                }
            ]
        };
    }

    function tickedOf(pool: var): var {
        return (pool.items ?? []).filter(item => item.on);
    }

    // CYCLE and SHUFFLE need something to move between; below two ticked
    // wallpapers a row behaves as SINGLE whatever its stored mode says.
    function effectiveMode(name: string): string {
        const pool = root.poolFor(name);
        return root.tickedOf(pool).length >= 2 ? (pool.mode ?? "SINGLE") : "SINGLE";
    }

    function absolute(relative: string): string {
        if (!relative)
            return "";
        if (relative.startsWith("/"))
            return relative;
        return folder ? `${folder}/${relative}` : "";
    }

    // Which wallpaper of a profile's pool is up. The rotation index only means
    // anything while the profile is cycling or shuffling.
    property var rotation: ({})

    function currentFile(name: string): string {
        const pool = root.poolFor(name);
        const ticked = root.tickedOf(pool);
        if (ticked.length === 0)
            return root.ownFile(name);
        if (root.effectiveMode(name) === "SINGLE")
            return ticked[0].file;
        // Only the active profile rotates. Any other -- one being previewed in
        // the picker -- shows where its rotation would start.
        if (name !== root.cyclingProfile)
            return ticked[root.startIndex(name)].file;
        const at = (root.rotation[name] ?? 0) % ticked.length;
        return ticked[at].file;
    }

    // Where a CYCLE starts: the profile's card wallpaper if it is ticked,
    // otherwise the first ticked one.
    function startIndex(name: string): int {
        const ticked = root.tickedOf(root.poolFor(name));
        const card = root.cardFile(name);
        const at = ticked.findIndex(item => item.file === card);
        return at >= 0 ? at : 0;
    }

    // The picker card's image: the starred wallpaper, or the first in the
    // pool, or the profile's own file when the pool is empty.
    function cardFile(name: string): string {
        const items = root.poolFor(name).items ?? [];
        const starred = items.find(item => item.star);
        if (starred)
            return starred.file;
        return items.length ? items[0].file : root.ownFile(name);
    }

    // **A url only once the file is really there.** A generated wallpaper is
    // written by a detached script, so for the second between the profile
    // being stored and the PNG landing the path exists and the file does not
    // -- and an `Image` handed a missing file fails once and never retries.
    // Holding the url empty until the listing has seen the file means the
    // source *changes* when it arrives, which is what makes it load.
    function imageOf(relative: string): url {
        const path = root.absolute(relative);
        if (!path || (root.listed && !root.hasFile(relative)))
            return "";
        return Paths.url(path);
    }

    function cardImage(name: string): url {
        return root.imageOf(root.cardFile(name));
    }

    // --- What is on screen --------------------------------------------------
    // `Theme.profile` is the previewed profile while the picker is previewing,
    // so a preview moves the wallpaper with it for free -- and only when
    // `dynamic` is on, which is exactly what the switch promises.
    readonly property string displayedPath: dynamic ? root.absolute(root.currentFile(Theme.profile)) : lockedFile
    // An empty url rather than `file:///` when nothing is set yet: the folder
    // is not known until the first-run probe answers, and an Image handed a
    // bare scheme logs an error for a directory it was never asked to open.
    // When the library file is not available yet (no folder on a fresh install,
    // or the PNG not generated), a preset profile falls back to its bundled
    // wallpaper so first boot is never a flat colour; a custom profile stays
    // empty and shows the solid Theme.deep.
    readonly property url displayed: {
        if (!root.dynamic)
            return lockedFile ? Paths.url(lockedFile) : root.presetAsset(Theme.profile);
        const own = root.imageOf(root.currentFile(Theme.profile));
        return String(own) !== "" ? own : root.presetAsset(Theme.profile);
    }

    // The crossfade length is the active pool's, so a slow shuffle can be set
    // to drift rather than cut.
    // The pool's own FADE where the user has set one; otherwise the shared
    // scale's wallpaper figure. 1.5 s used to be the default, which is nearly
    // twice what every other cross-fade in the shell runs at.
    readonly property int fadeDuration: Math.max(120, Math.round((root.poolFor(Theme.profile).fade ?? Appearance.duration.wallpaper / 1000) * 1000))

    function setDynamic(on: bool): void {
        if (on === dynamic)
            return;
        // Going off locks in whatever is on screen at this moment; going on
        // hands the wallpaper back to the profile immediately, rather than
        // leaving a switch that says it follows the profile while showing
        // something else.
        lockedFile = on ? "" : displayedPath;
        dynamic = on;
        write();
        if (on)
            root.restartRotation();
    }

    function setFolder(path: string): void {
        folder = path.trim().replace(/\/+$/, "");
        write();
        rescan();
    }

    function setPools(next: var): void {
        pools = next;
        write();
    }

    // A profile the user just made, or one whose pool was never stored: give
    // it the default pool so the pools screen shows it straight away.
    function seed(name: string): void {
        if (root.pools[name])
            return;
        const next = Object.assign({}, root.pools);
        next[name] = root.poolFor(name);
        root.setPools(next);
    }

    function forget(name: string): void {
        if (!root.pools[name])
            return;
        const next = Object.assign({}, root.pools);
        delete next[name];
        root.setPools(next);
    }

    // --- Cycling ------------------------------------------------------------
    // Only the active profile cycles, and only while the wallpaper is attached
    // to the profile at all. A locked wallpaper that kept rotating underneath
    // would be a wallpaper that is not locked.
    readonly property string cyclingProfile: Theme.activeProfile
    readonly property bool cycling: dynamic && root.effectiveMode(cyclingProfile) !== "SINGLE"

    Timer {
        id: cycle

        interval: Math.max(60, (root.poolFor(root.cyclingProfile).every ?? 15) * 60) * 1000
        running: root.cycling
        repeat: true
        onTriggered: root.advance(root.cyclingProfile)
    }

    // **A profile switch, or Dynamic coming back on, starts the rotation
    // afresh.** The wallpaper cross-fades at once to one of the new profile's
    // own -- CYCLE from its card wallpaper if ticked, else the first ticked;
    // SHUFFLE a random ticked one -- and the interval is counted from that
    // moment rather than left over from the previous profile's timer.
    function restartRotation(): void {
        const name = root.cyclingProfile;
        const ticked = root.tickedOf(root.poolFor(name));
        const rot = Object.assign({}, root.rotation);
        if (root.effectiveMode(name) === "SHUFFLE")
            rot[name] = Math.floor(Math.random() * ticked.length);
        else
            rot[name] = root.startIndex(name);
        root.rotation = rot;
        if (root.cycling)
            cycle.restart();
    }

    Connections {
        target: Theme

        function onActiveProfileChanged(): void {
            if (root.dynamic)
                root.restartRotation();
        }
    }

    function advance(name: string): void {
        const ticked = root.tickedOf(root.poolFor(name));
        if (ticked.length < 2)
            return;
        const at = (root.rotation[name] ?? 0) % ticked.length;
        let next = (at + 1) % ticked.length;
        if (root.effectiveMode(name) === "SHUFFLE") {
            // A shuffle that can pick what is already up is a shuffle that
            // sometimes does nothing visible, which reads as broken.
            do
                next = Math.floor(Math.random() * ticked.length);
            while (next === at && ticked.length > 1);
        }
        const rot = Object.assign({}, root.rotation);
        rot[name] = next;
        root.rotation = rot;
    }

    // --- The library --------------------------------------------------------
    // Two listings: the folder itself and its `wrayth` subfolder, which is
    // where every generated wallpaper lives. `stamp` is bumped to force a
    // re-read after the shell has written to either.
    property int stamp: 0

    // Video files join the library too (tagged LIVE); see `stillOf`.
    readonly property var imageSuffixes: ["*.png", "*.jpg", "*.jpeg", "*.webp", "*.bmp", "*.mp4", "*.webm", "*.mkv", "*.mov"]

    // --- Video wallpapers ---------------------------------------------------
    // A video plays only on the desktop background (Background.qml), muted,
    // and only while its workspace is empty, nothing is fullscreen and the
    // machine is on AC. Everywhere else -- the lockscreen, the blurred
    // backdrops, the picker's tiles -- and whenever it is paused, it is its
    // first frame: a still made once with ffmpeg into ~/.cache/wrayth/stills.
    readonly property string stillsFolder: `${Quickshell.env("HOME")}/.cache/wrayth/stills`
    function isVideo(path: string): bool {
        return /\.(mp4|webm|mkv|mov)$/i.test(String(path));
    }
    function stillPath(path: string): string {
        const clean = String(path).replace(/^file:\/\//, "");
        return `${stillsFolder}/${clean.replace(/[^A-Za-z0-9._-]/g, "_")}.png`;
    }
    // What an Image can show for a source: itself, or a video's still.
    function stillOf(source: url): url {
        const s = String(source);
        return isVideo(s) ? Paths.url(stillPath(s)) : source;
    }
    function makeStills(): void {
        const videos = library.filter(e => isVideo(e.file)).map(e => absolute(e.file));
        if (videos.length === 0 || stiller.running)
            return;
        stiller.command = ["sh", "-c", 'dir="$1"; shift; mkdir -p "$dir"; for v in "$@"; do s="$dir/$(printf %s "$v" | sed "s/[^A-Za-z0-9._-]/_/g").png"; [ -s "$s" ] || ffmpeg -loglevel error -y -i "$v" -frames:v 1 "$s"; done', "sh", stillsFolder].concat(videos);
        stiller.running = true;
    }
    Process {
        id: stiller
        onExited: root.stamp++
    }

    // --- Per screen ---------------------------------------------------------
    // A pool's `screens` is "same" (every screen shows the one wallpaper, as
    // before) or "per"; with "per", `perScreen` maps a monitor's name to a
    // file of that pool.
    function displayedFor(screen: string): url {
        const pool = poolFor(Theme.profile);
        if (!dynamic || pool.screens !== "per")
            return displayed;
        const file = (pool.perScreen ?? {})[screen];
        const own = file ? imageOf(file) : "";
        return String(own) !== "" ? own : displayed;
    }
    function setScreens(name: string, mode: string): void {
        const next = Object.assign({}, pools);
        next[name] = Object.assign({}, poolFor(name), { screens: mode === "per" ? "per" : "same" });
        setPools(next);
    }
    // PER SCREEN: a screen takes the next wallpaper of the pool.
    function nextForScreen(name: string, screen: string): void {
        const pool = poolFor(name);
        const ticked = tickedOf(pool);
        if (ticked.length === 0)
            return;
        const per = Object.assign({}, pool.perScreen ?? {});
        const at = ticked.findIndex(i => i.file === per[screen]);
        per[screen] = ticked[(at + 1) % ticked.length].file;
        const next = Object.assign({}, pools);
        next[name] = Object.assign({}, pool, { perScreen: per });
        setPools(next);
    }

    // `FolderListModel` reads its directory once and does not watch it, and it
    // has no reload method -- so a re-read is a nudge of `folder` through the
    // empty string and back. The shell writes into these folders itself
    // (generate, import, delete), so it always knows when to do this.
    function rescan(): void {
        stamp++;
        rootFiles.folder = "";
        netFiles.folder = "";
        relist.restart();
    }

    Timer {
        id: relist

        interval: 1
        onTriggered: {
            rootFiles.folder = root.folder ? Paths.url(root.folder) : "";
            netFiles.folder = root.wraythFolder ? Paths.url(root.wraythFolder) : "";
        }
    }

    // [{ file, name, tag }] -- `tag` is DEFAULT for a preset's wallpaper,
    // GENERATED for a custom profile's, and empty for anything else the user
    // has put in the folder.
    property var library: []
    // False until the folder has been read once. Before that nothing can be
    // said about whether a file exists, and gating on an unread listing would
    // blank every wallpaper for the first frames of a session.
    property bool listed: false

    function tagFor(relative: string): string {
        if (!relative.startsWith("wrayth/"))
            return "";
        for (const name of Profiles.names)
            if (root.ownFile(name) === relative)
                return Profiles.isCustom(name) ? "GENERATED" : "DEFAULT";
        return "";
    }

    function rebuildLibrary(): void {
        // Not while the listings are being nudged. `rescan` clears both
        // folders and sets them again a tick later, and both models report a
        // count of zero in between -- adopting that would empty the library
        // for a frame, and every image bound to it would fade out and back.
        if (relist.running)
            return;
        const out = [];
        const seen = {};
        const take = (model, prefix) => {
            for (let i = 0; i < model.count; i++) {
                const fileName = model.get(i, "fileName");
                const relative = `${prefix}${fileName}`;
                if (seen[relative])
                    continue;
                seen[relative] = true;
                out.push({
                    file: relative,
                    name: fileName,
                    tag: root.isVideo(relative) ? "LIVE" : root.tagFor(relative)
                });
            }
        };
        take(rootFiles, "");
        take(netFiles, "wrayth/");
        library = out;
        listed = true;
        makeStills();
    }

    onFolderChanged: root.rescan()

    FolderListModel {
        id: rootFiles

        Component.onCompleted: folder = root.folder ? Paths.url(root.folder) : ""
        nameFilters: root.imageSuffixes
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name

        onCountChanged: root.rebuildLibrary()
        onStatusChanged: if (status === FolderListModel.Ready) root.rebuildLibrary()
    }

    FolderListModel {
        id: netFiles

        Component.onCompleted: folder = root.wraythFolder ? Paths.url(root.wraythFolder) : ""
        nameFilters: root.imageSuffixes
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name

        onCountChanged: root.rebuildLibrary()
        onStatusChanged: if (status === FolderListModel.Ready) root.rebuildLibrary()
    }

    function hasFile(relative: string): bool {
        return root.library.some(entry => entry.file === relative);
    }

    // Any wrayth wallpaper still on disk, with the profile it belongs to --
    // what a RESTORE maps *from* when the profile's own file is gone.
    function restoreSource(): var {
        for (const name of Profiles.names) {
            const file = root.ownFile(name);
            if (root.hasFile(file))
                return {
                    name,
                    file
                };
        }
        return null;
    }

    // --- Shelling out -------------------------------------------------------
    // Single-quoted for `sh -c`, the only quoting that is safe for a path the
    // user typed or a filename they chose.
    function quote(text: string): string {
        return `'${String(text).replace(/'/g, "'\\''")}'`;
    }

    // Detached, not a shared `Process`: two of these can be in flight at once
    // -- a generate and a rescan, a delete and an import -- and one `Process`
    // object would have the second clobber the first. `sh` is always on the
    // PATH, which is the one thing `execDetached` cannot be relied on to find.
    function run(script: string): void {
        Quickshell.execDetached(["sh", "-c", script]);
    }

    // The folder is created on demand rather than at start-up: the shell does
    // not make directories in the user's Pictures until they ask it to.
    function openFolder(): void {
        if (!folder)
            return;
        // thunar by name, not `xdg-open`: this machine's handler for
        // `inode/directory` is the text editor, and OPEN FOLDER promises a
        // file manager. `xdg-open` is the fallback where thunar is absent.
        // Out of the deck first, so the file manager opens on the desktop.
        Deck.leave();
        run(`mkdir -p ${quote(folder)} ${quote(wraythFolder)} && (command -v thunar >/dev/null && exec thunar ${quote(folder)} || exec xdg-open ${quote(folder)})`);
        refresh.restart();
    }

    function importFiles(paths: var): void {
        if (!folder || !paths.length)
            return;
        const args = paths.map(p => quote(String(p).replace("file://", ""))).join(" ");
        run(`mkdir -p ${quote(folder)} && cp -n ${args} ${quote(folder)}/`);
        refresh.restart();
    }

    function deleteFile(relative: string): void {
        const path = absolute(relative);
        if (!path)
            return;
        run(`rm -f ${quote(path)}`);
        refresh.restart();
    }

    // --- Generating ---------------------------------------------------------
    // `wrayth-wallpaper` maps the base render's red to the profile's accent
    // and its cyan to the profile's signal. A restore maps from a surviving
    // wrayth wallpaper instead, using that profile's own two colours as the
    // source, which is the same mapping run from a different starting point.
    function generate(name: string, from: var): void {
        if (!wraythFolder)
            return;
        const palette = Profiles.palettes[name];
        if (!palette)
            return;
        const out = `${wraythFolder}/${generatedName(name)}`;
        let source = [Paths.baseRender, "#FF3B45", "#4FC3C9"];
        if (from) {
            const fromPalette = Profiles.palettes[from.name];
            source = [absolute(from.file), String(fromPalette.accent), String(fromPalette.signal)];
        }
        run(`mkdir -p ${quote(wraythFolder)} && ${quote(Paths.wallpaperScript)} --out ${quote(out)} --accent ${quote(String(palette.accent))} --signal ${quote(String(palette.signal))} --src ${quote(source[0])} --src-accent ${quote(source[1])} --src-signal ${quote(source[2])}`);
        refresh.restart();
    }

    function restore(name: string): void {
        const from = restoreSource();
        if (from)
            generate(name, from);
    }

    // The scripts above are detached, so nothing signals when they finish, and
    // a 1920x1080 recolour takes about half a second. Three re-reads over two
    // and a half seconds is what catches the file whenever it lands, without
    // polling the folder for the rest of the session.
    Timer {
        id: refresh

        interval: 800
        repeat: true
        triggeredOnStart: true
        property int left: 0

        onRunningChanged: if (running) left = 3
        onTriggered: {
            root.rescan();
            if (--left <= 0)
                running = false;
        }
    }

    // --- Persistence --------------------------------------------------------
    // False until the file has been read -- or found missing -- once. A
    // config reload rebuilds this singleton with empty pools and the FileView
    // loads asynchronously, so anything that writes in that window would
    // persist the *defaults* over whatever the user had set. Nothing writes
    // before the first read.
    property bool loaded: false

    function write(): void {
        if (!root.loaded)
            return;
        file.setText(`${JSON.stringify({
            dynamic: root.dynamic,
            folder: root.folder,
            lockedFile: root.lockedFile,
            pools: root.pools
        }, null, 2)}\n`);
    }

    function adopt(contents: string): void {
        // An empty file is a valid "nothing set yet", and it counts as read.
        if (!contents.trim()) {
            loaded = true;
            return;
        }
        try {
            const parsed = JSON.parse(contents);
            // **Types are checked, not assumed.** The file is hand-editable,
            // and a `folder` that is a number reaches `Paths.url` as a
            // hostname -- `folder: 42` produced `file://0.0.0.42/...` and
            // twenty "cannot open" warnings from every surface drawing a
            // wallpaper. A value of the wrong type is a value that was not
            // set, and the default stands.
            dynamic = typeof parsed.dynamic === "boolean" ? parsed.dynamic : true;
            folder = typeof parsed.folder === "string" ? parsed.folder : "";
            lockedFile = typeof parsed.lockedFile === "string" ? parsed.lockedFile : "";
            pools = parsed.pools && typeof parsed.pools === "object" && !Array.isArray(parsed.pools) ? parsed.pools : ({});
            loaded = true;
        } catch (e) {
            // Deliberately leaves `loaded` false: a file we cannot parse is
            // not a file we may overwrite with defaults.
            console.warn(`wrayth: wallpapers.json is not readable JSON (${e})`);
        }
    }

    // First run: the folder is prefilled only if ~/Pictures/wallpapers is
    // actually there. Pointing the field at a folder the user does not have
    // would put a path in front of them that means nothing.
    function seedFolder(): void {
        probe.exec(["sh", "-c", `test -d ${root.quote(Paths.defaultWallpaperRoot)} && echo yes || echo no`]);
    }

    Process {
        id: probe

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "yes" && !root.folder) {
                    root.folder = Paths.defaultWallpaperRoot;
                    root.write();
                }
            }
        }
    }

    FileView {
        id: file

        path: Paths.wallpapersFile
        watchChanges: true
        printErrors: false

        onLoaded: root.adopt(text())
        onFileChanged: reload()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.loaded = true;
                root.seedFolder();
            }
        }
    }
}
