pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The readouts only the HUD shows, so they poll only while the deck is up.
// Everything the bar ticker also needs lives in SystemStatus and runs all the
// time; see Polling in DESIGN.md.
Singleton {
    id: root

    readonly property bool active: ShellState.deckVisible

    // Package temperature in degrees C, -1 before the first read.
    property real tempC: -1
    // Mean core frequency in GHz.
    property real freqGhz: 0
    // TRACE: something is listening on 8080.
    property bool tracing: false

    Process {
        id: cpuProc

        // hwmon numbering is not stable across boots, so coretemp is found by
        // name rather than by path. Temperature and frequency come back from
        // one process because they are read on the same tick.
        command: ["sh", "-c", `
            for d in /sys/class/hwmon/hwmon*; do
                case "$(cat "$d/name" 2>/dev/null)" in
                    coretemp|k10temp|zenpower|cpu_thermal)
                        t=$(cat "$d/temp1_input" 2>/dev/null) && break ;;
                esac
            done
            f=$(cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_cur_freq 2>/dev/null | awk '{s+=$1;n++} END{if (n) print s/n}')
            echo "\${t:--1} \${f:-0}"
        `]

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                const milliC = Number(parts[0]);
                const khz = Number(parts[1]);
                root.tempC = isFinite(milliC) && milliC > 0 ? milliC / 1000 : -1;
                root.freqGhz = isFinite(khz) && khz > 0 ? khz / 1000000 : 0;
            }
        }
    }

    Process {
        id: traceProc

        // Non-empty output means something holds the port.
        command: ["sh", "-c", "ss -ltnH 'sport = :8080'"]
        stdout: StdioCollector {
            onStreamFinished: root.tracing = text.trim() !== ""
        }
    }

    Timer {
        interval: 2000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: cpuProc.running = true
    }

    Timer {
        interval: 5000
        running: root.active
        repeat: true
        triggeredOnStart: true
        onTriggered: traceProc.running = true
    }
}
