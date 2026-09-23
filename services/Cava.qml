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
        command: ["cava", "-p", Quickshell.shellPath("assets/cava.conf")]

        onRunningChanged: {
            if (running)
                return;
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
