pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// IDLE // AUTO or IDLE // HOLD, and the one thing that decides it.
//
// **It is persisted, and that is the whole point of this file.** The flag used
// to live on `ShellState`, which is rebuilt from scratch by every config
// reload -- and the shell reloads whenever any of its files changes, which
// during a build session is constantly. HOLD would be set, the shell would
// reload for an unrelated reason, and the machine would lock ten minutes
// later with the bar still reading HOLD on the previous frame. Measured: set
// HOLD, touch one file, and the state came back AUTO.
//
// The inhibitor itself is held by the bar window -- see `Bar.qml`. This only
// says whether it should be.
Singleton {
    id: root

    property bool hold: false

    // Nothing is written before the file has been read, or a reload would
    // save the default over whatever was there. Same rule as `Wallpapers`.
    property bool loaded: false

    function toggle(): void {
        root.hold = !root.hold;
    }

    function write(): void {
        if (!root.loaded)
            return;
        file.setText(`${root.hold ? "hold" : "auto"}\n`);
    }

    onHoldChanged: root.write()

    FileView {
        id: file

        path: Paths.idleFile
        watchChanges: true
        printErrors: false

        // `hold` is assigned before `loaded` is set, so restoring the saved
        // value does not immediately write it back.
        onLoaded: {
            root.hold = text().trim().toLowerCase() === "hold";
            root.loaded = true;
        }
        onFileChanged: reload()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound) {
                root.loaded = true;
                root.write();
            }
        }
    }
}
