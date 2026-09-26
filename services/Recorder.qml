pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Screen recording with wf-recorder: REGION (the screenshot selector), the
// focused WINDOW or the focused SCREEN; AUDIO off by default, or the system's
// output, or the output and the microphone; 30 or 60 frames a second. Saved to
// ~/Videos/Recordings and announced like a screenshot, with OPEN and DELETE.
//
// Super + Shift + R opens the RECORD panel, or stops a recording that is
// running; so does the REC chip on the bar.
Singleton {
    id: root

    readonly property string folder: `${Quickshell.env("HOME")}/Videos/Recordings`

    property string capture: "region"    // region | window | screen
    property string audio: "off"         // off | system | both
    property int fps: 60

    property bool recording: false
    property real startedAt: 0
    property string file: ""
    property bool available: false

    // Asked again whenever RECORD opens, so installing wf-recorder needs no
    // reload.
    function recheck(): void {
        if (!probe.running)
            probe.running = true;
    }
    Process {
        id: probe
        running: true
        command: ["sh", "-c", "command -v wf-recorder"]
        onExited: code => root.available = code === 0
    }

    function toggle(): void {
        if (recording)
            stop();
        else
            ShellState.openExclusive(ShellState.recordOpen ? "" : "record");
    }

    // From START RECORDING.
    function start(): void {
        ShellState.recordOpen = false;
        if (recording || !available)
            return;
        if (capture === "region") {
            Screenshot.forRecording = true;
            Screenshot.start("region");
            return;
        }
        if (capture === "window") {
            const w = Hyprland.activeToplevel?.lastIpcObject;
            if (w?.at)
                begin(`${w.at[0]},${w.at[1]} ${w.size[0]}x${w.size[1]}`, "");
            return;
        }
        begin("", ShellState.focusedScreen);
    }

    function stamp(): string {
        const d = new Date();
        const p = n => (n < 10 ? "0" : "") + n;
        return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}_${p(d.getHours())}-${p(d.getMinutes())}-${p(d.getSeconds())}`;
    }

    // geometry "x,y wxh" in layout coordinates, or an output name.
    function begin(geometry: string, output: string): void {
        file = `${folder}/Recording_${stamp()}.mp4`;
        const args = ["wf-recorder", "-y", "-f", file, "-r", String(fps)];
        if (geometry !== "")
            args.push("-g", geometry);
        else if (output !== "")
            args.push("-o", output);
        // System sound is the default output's monitor. wf-recorder takes one
        // audio device, so SYSTEM + MIC records the microphone beside it with
        // pw-record and mixes the two into the file when the recording stops.
        // No device is created or changed for this.
        if (audio !== "off")
            args.push("--audio=@DEFAULT_MONITOR@");
        proc.command = ["sh", "-c", root.script, "sh", folder, file, audio === "both" ? "1" : "0"].concat(args);
        proc.running = true;
        recording = true;
        startedAt = Date.now();
    }

    // Runs wf-recorder (and pw-record for the mic), stops both on SIGINT.
    readonly property string script: `dir="$1"; out="$2"; mix="$3"; shift 3
mkdir -p "$dir" || exit 1
if [ "$mix" != 1 ]; then exec "$@"; fi
tmp="\${out%.mp4}.part.mp4"; mic="\${out%.mp4}.mic.wav"
cmd=""; for a in "$@"; do [ "$a" = "$out" ] && a="$tmp"; cmd="$cmd '$a'"; done
pw-record "$mic" & m=$!
eval "$cmd" & w=$!
trap 'kill -INT $w $m 2>/dev/null' INT TERM
wait $w; wait $w 2>/dev/null; kill -INT $m 2>/dev/null; wait $m 2>/dev/null
ffmpeg -loglevel error -y -i "$tmp" -i "$mic" -filter_complex "[0:a][1:a]amix=inputs=2:duration=first[a]" -map 0:v -map "[a]" -c:v copy "$out" && rm -f "$tmp" "$mic"`

    function stop(): void {
        if (recording)
            proc.signal(2);
    }

    Process {
        id: proc

        onExited: code => {
            const f = root.file;
            root.recording = false;
            notify.exec(["sh", "-c", '[ -s "$1" ] || exit 1; notify-send -a Recording -u normal -h "string:x-wrayth-recording:$1" "Recording saved" "$(basename "$1")"', "sh", f]);
        }
    }
    Process {
        id: notify
    }

    // --- The notification's buttons ------------------------------------------
    function ours(f: string): bool {
        return f.startsWith(`${folder}/`) && !f.includes("/../") && f.endsWith(".mp4");
    }
    function open(f: string): void {
        if (ours(f))
            Deck.launch(["xdg-open", f]);
    }
    function remove(f: string): void {
        if (ours(f))
            helper.exec(["rm", "-f", "--", f]);
    }
    Process {
        id: helper
    }
}
