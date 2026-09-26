pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// What is using the microphone, the camera or the screen right now, for the
// bar's privacy chips. Metadata only: nothing is ever read from the devices.
//
//   MIC    an app's audio capture stream in PipeWire (the shell's own
//          visualiser, which listens to the output's monitor, excepted)
//   SHARE  the Hyprland portal's screen-cast stream (xdg-desktop-portal-
//          hyprland), which exists only while something is capturing
//   CAM    a camera stream in PipeWire, or /dev/video* held open by an app
//          (most browsers open the camera directly). The device files are
//          watched with inotify, so nothing polls: `fuser` runs only when
//          one is opened or closed.
//
// Each is a list of the apps responsible. `simulate` replaces them all, for
// tests, so no device is ever opened to see a chip.
Singleton {
    id: root

    readonly property var nodes: Pipewire.nodes?.values ?? []
    PwObjectTracker {
        objects: root.nodes.filter(n => n && (n.isStream || n.type === PwNodeType.VideoSource))
    }

    function propsOf(n: var): var {
        return n?.properties ?? {};
    }
    function nameOf(n: var): string {
        const p = propsOf(n);
        return (p["application.name"] || p["application.process.binary"] || n?.description || n?.name || "AN APP").trim();
    }

    readonly property var realMic: {
        const out = [];
        for (const n of nodes) {
            if (!n || propsOf(n)["media.class"] !== "Stream/Input/Audio")
                continue;
            const name = nameOf(n);
            // The visualiser reads the output's monitor, not the microphone.
            if (/^cava$/i.test(name) || (propsOf(n)["stream.capture.sink"] ?? "") === "true")
                continue;
            if (out.indexOf(name) < 0)
                out.push(name);
        }
        return out;
    }
    readonly property var realShare: {
        const out = [];
        for (const n of nodes) {
            const p = propsOf(n);
            if (!n || p["media.class"] !== "Video/Source")
                continue;
            if (/xdph|xdg-desktop-portal/i.test(`${n.name} ${p["application.name"] ?? ""}`))
                out.push(n);
        }
        // The app on the other end is not named by the portal's node; the
        // video streams reading it are.
        if (out.length === 0)
            return [];
        const readers = nodes.filter(n => n && propsOf(n)["media.class"] === "Stream/Input/Video").map(n => nameOf(n));
        return readers.length > 0 ? Array.from(new Set(readers)) : ["AN APP, THROUGH THE PORTAL"];
    }
    property var devCam: []
    readonly property var realCam: {
        const out = devCam.slice();
        for (const n of nodes) {
            const p = propsOf(n);
            if (n && p["media.class"] === "Stream/Input/Video" && realShare.length === 0) {
                const name = nameOf(n);
                if (out.indexOf(name) < 0)
                    out.push(name);
            }
        }
        return out;
    }

    // Tests: { mic: [...], cam: [...], share: [...] }, or null for real.
    property var simulated: null
    readonly property var mic: simulated ? (simulated.mic ?? []) : realMic
    readonly property var cam: simulated ? (simulated.cam ?? []) : realCam
    readonly property var share: simulated ? (simulated.share ?? []) : realShare

    // --- The camera device files ------------------------------------------------
    Process {
        id: camWatch

        running: true
        command: ["sh", "-c", 'ls /dev/video* >/dev/null 2>&1 || exec sleep infinity; command -v inotifywait >/dev/null || exec sleep infinity; exec inotifywait -mq -e open,close /dev/video*']
        stdout: SplitParser {
            onRead: camSettle.restart()
        }
    }
    Timer {
        id: camSettle
        interval: 400
        onTriggered: if (!camRead.running) camRead.running = true
    }
    // Which processes hold a camera open, by name. Our own inotifywait holds
    // nothing open (it watches), so it never counts itself.
    Process {
        id: camRead

        command: ["sh", "-c", 'for p in $(fuser /dev/video* 2>/dev/null); do cat "/proc/$p/comm" 2>/dev/null; done | sort -u']
        stdout: StdioCollector {
            onStreamFinished: root.devCam = text.split("\n").map(s => s.trim()).filter(s => s !== "")
        }
    }
    Component.onCompleted: camRead.running = true
}
