pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every path the shell reads or writes, in one place.
Singleton {
    id: root

    // **Keep the shell's own directories owner-only.** They hold the planner
    // (real task names), the launch history and the like -- personal, not
    // secret, but there is no reason for another local user to read them, and
    // FileView creates them at the process umask (usually world-readable 755).
    // Created 700 and re-tightened at every start; the paths are the user's own
    // home plus fixed names, passed as positional args so nothing is a shell
    // string.
    Process {
        id: dirGuard
        command: ["sh", "-c", "for d in \"$@\"; do mkdir -p -m 700 \"$d\" 2> /dev/null; chmod 700 \"$d\" 2> /dev/null; done", "sh", root.configDir, root.cacheDir, root.stateDir]
    }

    // Started from onCompleted, not `running: true`, so the command's path
    // arguments (derived properties) are resolved before it runs. Re-applied
    // once after start-up settles, because a config directory a FileView
    // creates as it writes its first default can land after the first pass and
    // would otherwise keep the umask's world-readable mode.
    function _guardDirs(): void {
        dirGuard.running = true;
    }

    Component.onCompleted: root._guardDirs()

    Timer {
        interval: 2500
        running: true
        onTriggered: root._guardDirs()
    }

    readonly property string home: Quickshell.env("HOME")

    // **A path shown to a person reads the home folder as `~`.** This is a
    // permanent display rule, not a demo-mode mask: `/home/<user>` in a label
    // leaks the username and is noise besides, and `~` is what a person reads
    // a path as anyway. The stored paths are always absolute; only the display
    // changes. Every label, field placeholder, tooltip and message that shows
    // a path goes through this.
    function display(path: string): string {
        if (!path)
            return path;
        if (path === home)
            return "~";
        if (path.startsWith(home + "/"))
            return "~" + path.slice(home.length);
        return path;
    }

    // The inverse, for a field that shows `~` and is typed back into.
    function expand(path: string): string {
        if (!path)
            return path;
        if (path === "~")
            return home;
        if (path.startsWith("~/"))
            return home + path.slice(1);
        return path;
    }

    readonly property string configDir: `${home}/.config/wrayth`
    readonly property string cacheDir: `${home}/.cache/wrayth`
    readonly property string stateDir: `${home}/.local/state/wrayth`

    readonly property string profileFile: `${configDir}/profile`
    readonly property string customProfilesFile: `${configDir}/custom-profiles.json`
    readonly property string wallpapersFile: `${configDir}/wallpapers.json`
    readonly property string effectsFile: `${configDir}/effects.json`
    readonly property string plannerFile: `${configDir}/planner.txt`
    readonly property string runnerFile: `${configDir}/runner`
    readonly property string statusFile: `${cacheDir}/status`
    readonly property string sessionFile: `${stateDir}/session`
    readonly property string launchesFile: `${stateDir}/launches`
    readonly property string idleFile: `${stateDir}/idle`
    // Marker that the one-time "short screen" notice has been shown; its mere
    // existence is the flag. Delete it (or the state dir) to see the notice again.
    readonly property string shortScreenFlag: `${stateDir}/shortscreen-notified`

    // The library folder the user points the picker at. It is only a default:
    // the real value is `Wallpapers.folder`, which is empty until this exists
    // or the user types a path. The `wrayth` subfolder inside it is where
    // the generated `net-*.png` wallpapers live -- both the presets', which
    // are already there, and every custom profile's.
    readonly property string defaultWallpaperRoot: `${home}/Pictures/wallpapers`
    readonly property string wallpaperDir: wraythSubfolder(defaultWallpaperRoot)

    function wraythSubfolder(root: string): string {
        return root ? `${root}/wrayth` : "";
    }

    // Called by an absolute path: ~/.local/bin is not necessarily on the PATH
    // the shell was started with, and execDetached fails silently when it is not.
    readonly property string profileScript: `${home}/.local/bin/wrayth-profile`
    readonly property string deckResetScript: `${home}/.local/bin/wrayth-deck-reset`
    readonly property string deckRefreshScript: `${home}/.local/bin/wrayth-deck-refresh`
    readonly property string daemonScript: `${home}/.local/bin/wrayth-daemon`
    readonly property string wallpaperScript: `${home}/.local/bin/wrayth-wallpaper`
    readonly property string unreadScript: `${home}/.local/bin/wrayth-unread`

    // The render every generated wallpaper is mapped from. It is inside the
    // shell rather than in the user's library, because the pools screen offers
    // to delete the library's files and generation must survive that.
    //
    // It is the shipped Circuit preset itself. A separate `assets/net-base.png`
    // used to sit beside it, pixel for pixel the same image (checked), which
    // was 3.9 MB of the repo carrying nothing; the mapping's source colours
    // (`#FF3B45` / `#4FC3C9`) are Circuit's either way.
    readonly property string baseRender: Quickshell.shellPath("assets/wallpapers/net-circuit.png")

    function wallpaperFor(profile: string): string {
        // Same sanitising as Wallpapers.generatedName: spaces to hyphens, every
        // other non-`[a-z0-9-]` character dropped. Keeps the read path inside
        // the wallpaper folder and matching the file the generator wrote.
        return `${wallpaperDir}/net-${profile.toLowerCase().replace(/ /g, "-").replace(/[^a-z0-9-]/g, "")}.png`;
    }

    // Path -> file:// url, for Image.source and friends.
    function url(path: string): url {
        return Qt.resolvedUrl(`file://${path}`);
    }
}
