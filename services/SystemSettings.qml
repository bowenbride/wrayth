pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// SYSTEM (the picker's third page): interface scale, motion, game mode and
// idle timings, saved to ~/.config/wrayth/system.json -- a file of its own,
// which updates never touch -- and applied live.
//
//   scale      { "<output>": 1.25, ... }; applied to Hyprland on choosing.
//   motion     "full" | "reduced": reduced swaps movement for quick fades and
//              turns glitches off.
//   game       "auto" | "off": AUTO pauses the visualiser, glitches, scanlines
//              and background updates while anything is fullscreen.
//   notify     "hold" | "show": whether notifications wait while fullscreen.
//   idleAc / idleBattery  { screenOff, lock, sleep } in minutes, 0 = never.
//              Lock always comes before sleep; see `fixIdle`.
Singleton {
    id: root

    readonly property string file: `${Quickshell.env("HOME")}/.config/wrayth/system.json`

    property var scale: ({})
    property string motion: "full"
    property string game: "auto"
    property string notify: "hold"
    // Optional features, off by default (and for anyone updating): the window
    // switcher (Alt + Tab) and the workspace overview (Super + Tab). Off, the
    // shell binds neither key and loads neither overlay.
    property bool switcher: false
    property bool overview: false

    readonly property string optionalFile: `${Quickshell.env("HOME")}/.config/wrayth/optional-binds.lua`
    function setOptional(which: string, on: bool): void {
        const was = which === "switcher" ? switcher : overview;
        if (which === "switcher")
            switcher = on;
        else
            overview = on;
        save();
        optionalWriter.setText(`-- Written by Wrayth's SYSTEM page: the optional binds that are on.\nreturn {\n    switcher = ${switcher},\n    overview = ${overview},\n}\n`);
        // On: bound live. Off: Hyprland's config is reloaded, which drops ours
        // and gives the key back to your own binds (binding a key takes it
        // from every other bind on it, so only a reload restores yours).
        if (on !== was)
            optionalApply.command = on ? ["hyprctl", "eval", "wrayth_apply_keybinds()"] : ["hyprctl", "reload"];
        optionalDelay.restart();
    }
    FileView {
        id: optionalWriter
        path: root.optionalFile
        printErrors: false
    }
    Timer {
        id: optionalDelay
        interval: 150
        onTriggered: if (optionalApply.command.length > 0) optionalApply.running = true
    }
    Process {
        id: optionalApply
        command: []
    }
    // Wrayth's hypridle.conf as shipped: lock at 10, screen off at 12, sleep
    // at 30, on AC and battery alike.
    property var idleAc: ({ screenOff: 12, lock: 10, sleep: 30 })
    property var idleBattery: ({ screenOff: 12, lock: 10, sleep: 30 })
    // Set once the timings have been changed here: from then on the shell
    // writes hypridle's config (see `writeIdle`).
    property bool idleManaged: false
    // The last correction made, for the page to flag: "" or a sentence.
    property string corrected: ""
    property bool loaded: false

    readonly property bool reducedMotion: motion === "reduced"
    // Game mode is on: AUTO and something fullscreen.
    readonly property bool gaming: game === "auto" && fullscreen
    readonly property bool fullscreen: {
        const active = (Hyprland.monitors?.values ?? []).map(m => m.activeWorkspace?.id);
        return (Hyprland.workspaces?.values ?? []).some(ws => ws && active.indexOf(ws.id) >= 0 && (ws.lastIpcObject?.hasfullscreen ?? false));
    }

    readonly property var scales: [1, 1.25, 1.5, 1.75, 2]

    function setScale(output: string, value: real): void {
        const next = Object.assign({}, scale);
        next[output] = value;
        scale = next;
        save();
        // Only the scale changes: the rest of the monitor rule stays as the
        // config has it.
        // hl.monitor is a config call, not a dispatcher, so it goes through
        // `hyprctl eval` (as the keybinds' re-apply does).
        Quickshell.execDetached(["hyprctl", "eval", `hl.monitor({ output = "${output}", mode = "preferred", position = "auto", scale = ${value} })`]);
    }
    function setMotion(v: string): void {
        motion = v === "reduced" ? "reduced" : "full";
        save();
    }
    function setGame(v: string): void {
        game = v === "off" ? "off" : "auto";
        save();
    }
    function setNotify(v: string): void {
        notify = v === "show" ? "show" : "hold";
        save();
    }

    // **Lock always comes before sleep.** A sleep sooner than the lock (or a
    // sleep with the lock off) would suspend an unlocked machine; the lock is
    // moved to the sleep time and the change is flagged.
    function fixIdle(t: var): var {
        const out = Object.assign({}, t);
        corrected = "";
        if (out.sleep > 0 && (out.lock === 0 || out.lock > out.sleep)) {
            out.lock = out.sleep;
            corrected = "LOCK MOVED TO COME BEFORE SLEEP";
        }
        return out;
    }
    function setIdle(power: string, key: string, minutes: int): void {
        const cur = power === "battery" ? idleBattery : idleAc;
        const next = Object.assign({}, cur);
        next[key] = minutes;
        const fixed = fixIdle(next);
        if (power === "battery")
            idleBattery = fixed;
        else
            idleAc = fixed;
        idleManaged = true;
        save();
        writeIdle();
    }

    // --- Applying the idle timings ---------------------------------------------
    // hypridle cannot tell AC from battery, so the shell writes the timings
    // for whichever the machine is on to ~/.config/wrayth/hypridle.conf and
    // restarts hypridle with it -- when a timing changes, and when the power
    // source does. IDLE HOLD is an idle inhibitor, which hypridle respects
    // whatever its timings, so it still overrides everything.
    readonly property string idleFile: `${Quickshell.env("HOME")}/.config/wrayth/hypridle.conf`
    readonly property bool onBattery: Power.onBattery
    onOnBatteryChanged: if (idleManaged) writeIdle()
    function writeIdle(): void {
        const t = onBattery && Power.present ? idleBattery : idleAc;
        const lock = "qs -c wrayth ipc call lock lock";
        const parts = [`# Written by Wrayth's SYSTEM page (${onBattery ? "on battery" : "plugged in"}). Changes here are replaced.
general {
    lock_cmd = ${lock}
    before_sleep_cmd = ${lock}
    after_sleep_cmd = hyprctl dispatch 'hl.dsp.dpms({action = "on"})'
}
`];
        if (t.lock > 0)
            parts.push(`listener {\n    timeout = ${t.lock * 60}\n    on-timeout = ${lock}\n}\n`);
        if (t.screenOff > 0)
            parts.push(`listener {\n    timeout = ${t.screenOff * 60}\n    on-timeout = hyprctl dispatch 'hl.dsp.dpms({action = "off"})'\n    on-resume = hyprctl dispatch 'hl.dsp.dpms({action = "on"})'\n}\n`);
        if (t.sleep > 0)
            parts.push(`listener {\n    timeout = ${t.sleep * 60}\n    on-timeout = systemctl suspend\n}\n`);
        idleWriter.setText(parts.join("\n"));
        restartIdle.restart();
    }
    FileView {
        id: idleWriter
        path: root.idleFile
        printErrors: false
    }
    Timer {
        id: restartIdle
        interval: 200
        onTriggered: Quickshell.execDetached(["sh", "-c", 'command -v hypridle >/dev/null || exit 0; pkill -x hypridle; sleep 0.3; setsid -f hypridle -c "$1" >/dev/null 2>&1', "sh", root.idleFile])
    }

    function save(): void {
        if (!loaded)
            return;
        writer.setText(JSON.stringify({ scale: scale, motion: motion, game: game, notify: notify, idleAc: idleAc, idleBattery: idleBattery, idleManaged: idleManaged, switcher: switcher, overview: overview }, null, 2) + "\n");
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
                root.scale = s.scale ?? {};
                root.motion = s.motion === "reduced" ? "reduced" : "full";
                root.game = s.game === "off" ? "off" : "auto";
                root.notify = s.notify === "show" ? "show" : "hold";
                if (s.idleAc)
                    root.idleAc = root.fixIdle(s.idleAc);
                if (s.idleBattery)
                    root.idleBattery = root.fixIdle(s.idleBattery);
                root.idleManaged = !!s.idleManaged;
                root.switcher = s.switcher === true;
                root.overview = s.overview === true;
                root.corrected = "";
                root.loaded = true;
            } catch (e) {
                // Never saved over: a file that does not parse stays as it is
                // (as effects.json and wallpapers.json do), so a hand edit
                // with a typo is not replaced by defaults on the next change.
                console.warn(`wrayth: system.json is not readable JSON (${e}); it is left as it is and not saved over`);
            }
        }
        onLoadFailed: root.loaded = true
    }
}
