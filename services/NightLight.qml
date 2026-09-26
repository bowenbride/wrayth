pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// NIGHT LIGHT: a warmer screen through hyprsunset. On by hand (MANUAL) or
// between two times of your choosing (SET TIMES). **No location is ever
// used** -- there is no sunset lookup and nothing is asked of the network.
//
// Settings live in ~/.config/wrayth/nightlight.json, which updates never
// touch. Nothing polls: with SET TIMES a single timer is set for the next
// FROM or TO, and set again when it fires.
//
// Without hyprsunset installed everything here still works as settings;
// `available` is false and nothing is applied (the dropdown says so).
Singleton {
    id: root

    readonly property string file: `${Quickshell.env("HOME")}/.config/wrayth/nightlight.json`

    property bool on: false
    property int kelvin: 4500
    property string schedule: "manual"   // "manual" | "times"
    property string from: "21:00"
    property string to: "07:00"

    property bool available: false
    property bool loaded: false

    readonly property int minKelvin: 2500
    readonly property int maxKelvin: 6500
    readonly property int steps: 20

    // Is it warm right now: MANUAL follows ON; SET TIMES is on between FROM
    // and TO (across midnight when TO is earlier), and ON still has to be on.
    property real now: Date.now()
    readonly property bool inWindow: {
        const d = new Date(now);
        const m = d.getHours() * 60 + d.getMinutes();
        const f = minutesOf(from), t = minutesOf(to);
        if (f < 0 || t < 0 || f === t)
            return false;
        return f < t ? (m >= f && m < t) : (m >= f || m < t);
    }
    readonly property bool active: on && (schedule === "manual" || inWindow)

    function minutesOf(hhmm: string): int {
        const m = /^([01]\d|2[0-3]):([0-5]\d)$/.exec(hhmm ?? "");
        return m ? parseInt(m[1]) * 60 + parseInt(m[2]) : -1;
    }
    function validTime(hhmm: string): bool {
        return minutesOf(hhmm) >= 0;
    }

    // Segments lit for a temperature, and back: 1 segment is the coolest step.
    function segmentsOf(k: int): int {
        return Math.round((maxKelvin - k) / (maxKelvin - minKelvin) * steps);
    }
    function kelvinOf(n: int): int {
        return Math.round((maxKelvin - n / steps * (maxKelvin - minKelvin)) / 100) * 100;
    }

    function setOn(v: bool): void {
        on = v;
        save();
    }
    function setKelvin(k: int): void {
        kelvin = Math.max(minKelvin, Math.min(maxKelvin, k));
        save();
    }
    function setSchedule(s: string): void {
        schedule = s === "times" ? "times" : "manual";
        save();
    }
    function setTimes(f: string, t: string): bool {
        if (!validTime(f) || !validTime(t))
            return false;
        from = f;
        to = t;
        save();
        return true;
    }

    // --- Applying ------------------------------------------------------------
    onActiveChanged: applyLater.restart()
    onKelvinChanged: applyLater.restart()
    onLoadedChanged: applyLater.restart()
    onAvailableChanged: applyLater.restart()
    // A drag across the segments applies once, at the end.
    Timer {
        id: applyLater
        interval: 150
        onTriggered: root.apply()
    }
    function apply(): void {
        if (!loaded || !available)
            return;
        if (active)
            applier.exec(["sh", "-c", 'if pgrep -x hyprsunset >/dev/null; then hyprctl hyprsunset temperature "$1" >/dev/null; else setsid -f hyprsunset -t "$1" >/dev/null 2>&1; fi', "sh", String(kelvin)]);
        else
            applier.exec(["sh", "-c", 'pgrep -x hyprsunset >/dev/null && hyprctl hyprsunset identity >/dev/null; exit 0']);
    }
    Process {
        id: applier
    }

    Process {
        running: true
        command: ["sh", "-c", "command -v hyprsunset"]
        onExited: code => root.available = code === 0
    }

    // --- The schedule's one timer ------------------------------------------
    function rearm(): void {
        now = Date.now();
        if (!on || schedule !== "times") {
            edge.stop();
            return;
        }
        const d = new Date(now);
        const m = d.getHours() * 60 + d.getMinutes();
        const next = [minutesOf(from), minutesOf(to)].filter(x => x >= 0).map(x => (x - m + 1440) % 1440 || 1440);
        if (next.length === 0)
            return;
        edge.interval = Math.min(...next) * 60000 - d.getSeconds() * 1000 - d.getMilliseconds() + 500;
        edge.restart();
    }
    Timer {
        id: edge
        onTriggered: root.rearm()
    }
    onOnChanged: rearm()
    onScheduleChanged: rearm()
    onFromChanged: rearm()
    onToChanged: rearm()

    // --- Settings file -------------------------------------------------------
    function save(): void {
        if (!loaded)
            return;
        writer.setText(JSON.stringify({ on: on, kelvin: kelvin, schedule: schedule, from: from, to: to }, null, 2) + "\n");
    }
    FileView {
        id: writer
        path: root.file
        printErrors: false
    }
    FileView {
        path: root.file
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.on = !!s.on;
                root.kelvin = Math.max(root.minKelvin, Math.min(root.maxKelvin, s.kelvin ?? 4500));
                root.schedule = s.schedule === "times" ? "times" : "manual";
                if (root.validTime(s.from))
                    root.from = s.from;
                if (root.validTime(s.to))
                    root.to = s.to;
            } catch (e) {}
            root.loaded = true;
            root.rearm();
        }
        onLoadFailed: {
            root.loaded = true;
            root.rearm();
        }
    }
}
