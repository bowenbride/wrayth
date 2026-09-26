pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The spectrum behind the signal panel.
//
// **cava runs whether or not the deck is up.** It used to be gated on
// `ShellState.deckVisible`, which meant the process was spawned cold every
// time the deck opened -- measured at **405 ms to its first frame**, three
// runs within 2 ms of each other, against the deck's own 400 ms fade. The
// spectrum sat dead through the whole opening animation and then snapped to
// life, which read as the visualiser freezing or resetting on every open
// rather than the deck arriving over something already running.
//
// The trade is a process up for the life of the session: **1.2% of one core
// and about 15 MB**, measured from /proc. If that ever matters more than the
// transition does, putting `ShellState.deckVisible` back here is the whole of
// the change.
Singleton {
    id: root

    readonly property bool active: true
    readonly property int bars: 48

    // **Paused, not stopped, while the deck is down.** cava is SIGSTOPped once
    // the deck has finished closing and SIGCONTed the moment it starts to
    // open: the process, its PipeWire stream and its buffers stay exactly as
    // they were, so the first frame after a resume arrives at once (no 405 ms
    // cold start), and a stopped process costs nothing. It used to run, and be
    // read, the whole session for a panel almost always hidden -- about 2% of
    // a core, the largest single part of the shell's idle cost.
    // Paused while game mode is on (SYSTEM page).
    readonly property bool wanted: ShellState.deckVisible && !SystemSettings.gaming
    property bool _paused: false
    function _pause(on: bool): void {
        if (!cava.running || on === root._paused)
            return;
        cava.signal(on ? 19 : 18); // SIGSTOP : SIGCONT
        root._paused = on;
    }
    // A reload tears this down: never leave a stopped cava behind.
    Component.onDestruction: _pause(false)
    onWantedChanged: {
        if (wanted) {
            pauseLater.stop();
            _pause(false);
        } else {
            pauseLater.restart();
        }
    }
    // Long enough for the deck's close to finish with the spectrum still live.
    Timer {
        id: pauseLater

        interval: 1000
        onTriggered: if (!root.wanted) root._pause(true)
    }

    readonly property string runtimeDir: `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/wrayth`
    // **It follows the selected source only while the deck is up.** A browser
    // creates and drops audio streams as its pages play and pause, and each
    // change re-pointed cava -- a restart, with the deck closed and nothing to
    // show. While the deck is down the source is held; opening it catches up.
    property string source: "auto"
    Component.onCompleted: source = Media.cavaSource
    Binding {
        target: root
        property: "source"
        when: root.wanted
        value: Media.cavaSource
        restoreMode: Binding.RestoreNone
    }
    // A single stream that gives nothing for 3 s while its player is playing
    // and the deck is up: marked silent, and the spectrum takes the whole
    // output instead of showing a flat line.
    Timer {
        interval: 3000
        running: root.wanted && root.source !== "auto" && !root.live && (Media.player?.isPlaying ?? false)
        onTriggered: {
            const next = Object.assign({}, Media.silentStreams);
            next[root.source] = true;
            Media.silentStreams = next;
        }
    }
    property bool switching: false
    // A new source: cava is restarted on it (a cold start is ~400 ms, and
    // only happens when the source actually changes).
    onSourceChanged: {
        if (!cava.running)
            return;
        switching = true;
        _pause(false); // a stopped process would not act on the SIGTERM
        cava.running = false;
    }

    // **cava keeps running; the shell stops reading every frame of it.**
    // Leaving the process up is what makes the spectrum live the instant the
    // deck opens -- see the note above, and the 405 ms cold start it exists
    // to avoid. Parsing all 60 frames a second into a 48-element array that
    // nothing is looking at is a different question, and it measured **0.6%
    // of a core**: 5.48% against 4.87% with cava stopped, over 60 s and 45 s.
    //
    // While the deck is down, one frame in six is taken. `levels` is then at
    // most 100 ms stale when the deck opens, against a 400 ms fade -- which
    // is to say it is current -- and the reading behind `live` still lands
    // six times a second against a 900 ms quiet timer.
    readonly property int idleEvery: 6
    property int _skipped: 0

    // One 0..1 value per bar, left to right.
    property var levels: []
    // Anything actually coming out of the speakers. Falls to false a moment
    // after the audio stops, so the panel settles rather than flickering.
    property bool live: false

    // **It restarts.** `running: root.active` starts cava once; the process
    // exiting -- a crash, PipeWire restarting under it, somebody killing it
    // -- left the deck's spectrum a flat line for the rest of the session
    // with no way back but a shell restart. Measured: killed, and gone
    // eighteen seconds later.
    //
    // The backoff is what keeps a cava that cannot run at all from becoming a
    // spawn loop, and the levels are dropped on the way down so the panel
    // does not sit holding the last frame it saw.
    Process {
        id: cava

        running: root.active
        // **It follows the selected source** (Media.cavaSource: a PipeWire
        // stream's serial, or "auto" for every sound). The config is the
        // shipped one with its `source` line replaced, written to the runtime
        // dir; the serial arrives as an argument, never spliced into the
        // script, and is digits or "auto" by construction.
        command: ["sh", "-c", 'mkdir -p "$1" && sed "s/^source = .*/source = $2/" "$3" > "$1/cava.conf" && exec cava -p "$1/cava.conf"',
            "sh", root.runtimeDir, root.source, Quickshell.shellPath("assets/cava.conf")]

        onRunningChanged: {
            root._paused = false;
            if (running) {
                if (!root.wanted)
                    pauseLater.restart();
                return;
            }
            if (root.switching) {
                root.switching = false;
                running = true;
                return;
            }
            root.levels = [];
            root.live = false;
            quiet.stop();
            if (root.active)
                revive.restart();
        }

        stdout: SplitParser {
            splitMarker: "\n"

            onRead: line => {
                if (!line)
                    return;
                if (!ShellState.deckVisible) {
                    if (++root._skipped < root.idleEvery)
                        return;
                }
                root._skipped = 0;
                const parts = line.split(";");
                const values = [];
                let peak = 0;
                // cava ends every frame with a trailing separator.
                for (let i = 0; i < parts.length; i++) {
                    if (parts[i] === "")
                        continue;
                    const value = Math.max(0, Math.min(1, Number(parts[i]) / 100));
                    values.push(value);
                    if (value > peak)
                        peak = value;
                }
                if (values.length === 0)
                    return;
                root.levels = values;
                if (peak > 0.02) {
                    root.live = true;
                    quiet.restart();
                }
            }
        }
    }

    Timer {
        id: revive

        interval: 3000
        onTriggered: if (root.active) cava.running = true
    }

    // Silence has to last a moment before the panel calls it silence.
    Timer {
        id: quiet

        interval: 900
        onTriggered: root.live = false
    }

    // Kept for the case where `active` is gated again: without it a restart
    // would come back holding the last frame from before it stopped.
    onActiveChanged: {
        if (!active) {
            levels = [];
            live = false;
            quiet.stop();
        }
    }
}
