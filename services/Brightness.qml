pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The panel backlight. sysfs does emit inotify events for `brightness`, so this
// watches the file rather than polling it -- confirmed against brightnessctl.
Singleton {
    id: root

    property string device: ""
    property real raw: -1
    property real max: 0

    readonly property real value: max > 0 && raw >= 0 ? raw / max : 0
    readonly property bool ready: max > 0 && raw >= 0

    // The label in the OSD popup, derived from the backlight device the glob
    // found (e.g. "INTEL", "AMDGPU_BL0") rather than a hard-coded connector
    // name, so it is right on any machine. "SCREEN" when nothing is detected.
    readonly property string outputName: {
        const m = device.match(/\/([^\/]+)\/?$/);
        if (!m)
            return "SCREEN";
        const n = m[1].replace(/_?backlight$/i, "").toUpperCase();
        return n || "SCREEN";
    }

    Process {
        running: true
        command: ["sh", "-c", "ls -d /sys/class/backlight/*/ 2>/dev/null | head -1"]
        stdout: StdioCollector {
            onStreamFinished: root.device = text.trim()
        }
    }

    // **Built only once the node is known.** A `FileView` with an empty path
    // registers an empty path with `QFileSystemWatcher`, which warns
    // `removePath: path is empty` the moment the real one replaces it -- one
    // warning per session, in the log, for nothing. A machine with no
    // backlight builds neither of these at all.
    Loader {
        active: root.device !== ""

        sourceComponent: FileView {
            path: `${root.device}brightness`
            watchChanges: true
            printErrors: false

            onFileChanged: reload()
            onLoaded: {
                const value = Number(text().trim());
                if (isFinite(value))
                    root.raw = value;
            }
        }
    }

    Loader {
        active: root.device !== ""

        sourceComponent: FileView {
            path: `${root.device}max_brightness`
            printErrors: false

            onLoaded: {
                const value = Number(text().trim());
                if (isFinite(value))
                    root.max = value;
            }
        }
    }
}
