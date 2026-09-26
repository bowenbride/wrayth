pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.services

// Screenshots. Print opens the shell's region selector (CaptureOverlay);
// Alt + Print takes the focused window and Shift + Print the whole focused
// screen at once. The image goes to ~/Pictures/Screenshots under a
// timestamped name and onto the clipboard, and a notification carries a
// thumbnail with OPEN, COPY and DELETE.
//
// Captured with `grim`, in Hyprland's layout coordinates, so it is right on
// any monitor at any scale; copied with `wl-copy`. **The selector never
// appears in the image**: it is hidden, and its layer has no fade (see the
// `wrayth-capture` rule), before grim runs.
Singleton {
    id: root

    // The selector's mode: "region", "window" or "screen".
    property string mode: "region"
    readonly property var modes: ["region", "window", "screen"]
    property bool busy: false

    readonly property string folder: `${Quickshell.env("HOME")}/Pictures/Screenshots`
    // The last one taken, for the tests.
    property string last: ""

    function stamp(): string {
        const d = new Date();
        const p = n => String(n).padStart(2, "0");
        return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}_${p(d.getHours())}-${p(d.getMinutes())}-${p(d.getSeconds())}`;
    }

    // Print: the selector on the focused screen. Alt/Shift + Print: at once.
    function start(which: string): string {
        if (busy || ShellState.locked)
            return "busy";
        if (which === "window")
            return captureWindow();
        if (which === "screen")
            return captureScreen(ShellState.focusedScreen);
        mode = "region";
        ShellState.openExclusive("capture");
        return "selector";
    }

    // A monitor's box in Hyprland's layout coordinates, and its scale. Every
    // capture is by geometry with the monitor's own scale passed to grim, so
    // the image has exactly the pixels the screen does, fractional scales
    // included (grim's own guess from an output can be off).
    // Every capture is by geometry in Hyprland's layout coordinates, with the
    // monitor's own scale passed to grim, so the image has exactly the pixels
    // the screen does, fractional scales included. The monitor figures are
    // Hyprland's, asked for afresh at the moment of capture: a cached copy
    // (or the output's own report) can lag a mode or scale change.
    function monitorBox(name: string): var {
        const m = (Hyprland.monitors?.values ?? []).find(x => x.name === name)?.lastIpcObject;
        if (!m)
            return null;
        return { x: m.x, y: m.y, w: Math.round(m.width / m.scale), h: Math.round(m.height / m.scale), scale: m.scale };
    }
    function scaleAt(px: real, py: real): real {
        for (const mon of Hyprland.monitors?.values ?? []) {
            const m = mon.lastIpcObject;
            if (m && px >= m.x && px < m.x + m.width / m.scale && py >= m.y && py < m.y + m.height / m.scale)
                return m.scale;
        }
        return 1;
    }

    property string queued: ""
    property string queuedScreen: ""
    function captureWindow(): string {
        if (!ActiveWindow.present)
            return "no window";
        queued = "window";
        Hyprland.refreshMonitors();
        fresh.restart();
        return "window";
    }
    function captureScreen(output: string): string {
        if (!output)
            return "no screen";
        queued = "screen";
        queuedScreen = output;
        Hyprland.refreshMonitors();
        fresh.restart();
        return "screen";
    }
    Timer {
        id: fresh
        interval: 150
        onTriggered: {
            if (root.queued === "window") {
                const cx = ActiveWindow.x + ActiveWindow.width / 2, cy = ActiveWindow.y + ActiveWindow.height / 2;
                root.run(`${ActiveWindow.x},${ActiveWindow.y} ${ActiveWindow.width}x${ActiveWindow.height}`, root.scaleAt(cx, cy));
            } else if (root.queued === "screen") {
                const b = root.monitorBox(root.queuedScreen);
                if (b)
                    root.run(`${b.x},${b.y} ${b.w}x${b.h}`, b.scale);
            }
            root.queued = "";
        }
    }

    // From the selector: global layout geometry, taken after it has gone.
    property var pending: null
    // Set by RECORD: the next region chosen starts a recording instead.
    property bool forRecording: false
    function captureFromSelector(geometry: string, scale: real): void {
        ShellState.captureOpen = false;
        if (forRecording) {
            forRecording = false;
            Recorder.begin(geometry, "");
            return;
        }
        pending = { geometry: geometry, scale: scale };
        settle.restart();
    }
    // Long enough for the unmapped selector to leave the next frame.
    Timer {
        id: settle
        interval: 150
        onTriggered: {
            if (root.pending)
                root.run(root.pending.geometry, root.pending.scale);
            root.pending = null;
        }
    }

    // What the last capture asked grim for: for the tests.
    property string lastGeometry: ""
    function run(geometry: string, scale: real): string {
        busy = true;
        root.lastGeometry = `${geometry} @${scale}`;
        const file = `${folder}/Screenshot_${stamp()}.png`;
        root.last = file;
        shot.file = file;
        shot.command = ["sh", "-c", 'mkdir -p "$1" && grim -s "$4" -g "$3" "$2" && { wl-copy --type image/png < "$2" || true; }', "sh", folder, file, geometry, String(scale)];
        shot.running = true;
        return file;
    }

    Process {
        id: shot

        property string file: ""

        onExited: code => {
            root.busy = false;
            if (code !== 0) {
                Notifications.send("Screenshot failed", "grim could not capture the screen. Is grim installed?");
                return;
            }
            const name = file.split("/").pop();
            notify.exec(["notify-send", "-a", "Screenshot", "-u", "normal",
                "-h", `string:image-path:${file}`, "-h", `string:x-wrayth-screenshot:${file}`,
                "Screenshot saved", `${name}, copied to the clipboard`]);
        }
    }
    Process {
        id: notify
    }

    // --- The notification's buttons ----------------------------------------
    // Only ever for a file in the screenshots folder.
    function ours(file: string): bool {
        return file.startsWith(`${folder}/`) && !file.includes("/../") && file.endsWith(".png");
    }
    function open(file: string): void {
        if (ours(file))
            Deck.launch(["xdg-open", file]);
    }
    function copy(file: string): void {
        if (ours(file))
            helper.exec(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", file]);
    }
    function remove(file: string): void {
        if (ours(file))
            helper.exec(["rm", "-f", "--", file]);
    }
    Process {
        id: helper
    }
}
