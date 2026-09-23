pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// The daemon library: which readouts the HUD is showing, what they say, and
// the catalogue the picker offers.
//
// Every reading comes from one helper, `wrayth-daemon <id>`, which prints
// `VALUE|TONE|DETAIL`. Keeping the probes in a shell script rather than in QML
// is what lets each one be tested on its own from a terminal.
Singleton {
    id: root

    readonly property int maxSelected: 5

    readonly property var catalogue: [
        { id: "ping", category: "NETWORK", name: "PING", description: "Round-trip time to a city you choose" },
        { id: "dns", category: "NETWORK", name: "DNS", description: "Which resolver is in use, and how fast it answers" },
        { id: "vpn", category: "NETWORK", name: "VPN", description: "Whether a tunnel is up" },
        { id: "wifi", category: "NETWORK", name: "WIFI", description: "Signal strength and how the network is secured" },
        { id: "ports", category: "NETWORK", name: "PORTS", description: "Services on this machine that accept connections" },
        { id: "connections", category: "NETWORK", name: "CONNECTIONS", description: "Outbound connections, and which program has the most" },
        { id: "shield", category: "SECURITY", name: "SHIELD", description: "Which firewall is running, if any" },
        { id: "trace", category: "SECURITY", name: "TRACE", description: "An intercepting proxy listening locally" },
        { id: "ice", category: "SECURITY", name: "ICE", description: "System services that have failed since boot" },
        { id: "auth", category: "SECURITY", name: "AUTH", description: "Failed login and sudo attempts since boot" },
        { id: "ssh", category: "SECURITY", name: "SSH", description: "Whether anything can log into this machine remotely" },
        { id: "usb", category: "SECURITY", name: "USB", description: "Attached USB devices, and whether the set changed" },
        { id: "miccam", category: "SECURITY", name: "MIC / CAM", description: "Whether the microphone or camera is open" },
        { id: "battery", category: "SYSTEM", name: "BATTERY", description: "How much capacity the battery has lost" },
        { id: "thermal", category: "SYSTEM", name: "THERMAL", description: "Whether the CPU is slowing itself for heat" },
        { id: "disk", category: "SYSTEM", name: "DISK", description: "Free space on the root filesystem" },
        { id: "time", category: "SYSTEM", name: "TIME", description: "Whether the clock is synchronised" },
        { id: "reboot", category: "SYSTEM", name: "REBOOT", description: "Whether a kernel update is waiting on a restart" },
        { id: "docker", category: "LAB", name: "DOCKER", description: "Running containers" },
        { id: "lab", category: "LAB", name: "LAB TARGETS", description: "Whether your practice environments answer" }
    ]

    readonly property var categories: ["NETWORK", "SECURITY", "SYSTEM", "LAB"]

    // The spec's default selection.
    readonly property var defaultSelection: ["ping", "shield", "trace", "ice"]

    property var selected: defaultSelection
    // A neutral default (also the fallback in wrayth-daemon);
    // the user picks theirs in the daemon's detail view.
    property string pingTarget: "ec2.us-east-1.amazonaws.com"

    // Every target was checked before it went in: all twelve answered, every
    // one over TCP, because they all drop ICMP.
    readonly property var pingTargets: [
        { name: "VANCOUVER", host: "ec2.ca-west-1.amazonaws.com" },
        { name: "TORONTO", host: "ec2.ca-central-1.amazonaws.com" },
        { name: "SEATTLE", host: "ec2.us-west-2.amazonaws.com" },
        { name: "NEW YORK", host: "ec2.us-east-1.amazonaws.com" },
        { name: "SAO PAULO", host: "ec2.sa-east-1.amazonaws.com" },
        { name: "LONDON", host: "ec2.eu-west-2.amazonaws.com" },
        { name: "FRANKFURT", host: "ec2.eu-central-1.amazonaws.com" },
        { name: "STOCKHOLM", host: "ec2.eu-north-1.amazonaws.com" },
        { name: "MUMBAI", host: "ec2.ap-south-1.amazonaws.com" },
        { name: "SINGAPORE", host: "ec2.ap-southeast-1.amazonaws.com" },
        { name: "TOKYO", host: "ec2.ap-northeast-1.amazonaws.com" },
        { name: "SYDNEY", host: "ec2.ap-southeast-2.amazonaws.com" }
    ]

    // id -> { value, tone, detail, rows }
    property var readings: ({})

    // A short rolling history of ping latencies (ms) for the detail sparkline,
    // reset when the target changes.
    property var pingHistory: []

    // Which HUD row is open. One at a time.
    property string expanded: ""
    property bool libraryOpen: false

    function entry(id: string): var {
        return catalogue.find(d => d.id === id) ?? null;
    }

    function selectedEntries(): var {
        return selected.map(id => entry(id)).filter(e => e !== null);
    }

    function isSelected(id: string): bool {
        return selected.includes(id);
    }

    // At the cap the rest dim rather than disappearing: the list is a menu, not
    // a moving target.
    function atCap(): bool {
        return selected.length >= maxSelected;
    }

    function toggle(id: string): void {
        if (isSelected(id)) {
            selected = selected.filter(x => x !== id);
            if (expanded === id)
                expanded = "";
        } else if (!atCap()) {
            selected = selected.concat([id]);
        }
        _save();
    }

    function setPingTarget(host: string): void {
        pingTarget = host;
        pingHistory = [];
        _save();
        readings = Object.assign({}, readings, { ping: undefined });
    }

    function toneColor(tone: string): color {
        if (tone === "accent")
            return Theme.accent;
        if (tone === "alert")
            return Theme.alert;
        if (tone === "dim")
            return Theme.dim;
        return Theme.signal;
    }

    function _save(): void {
        file.setText(`selected=${selected.join(",")}\nping=${pingTarget}\n`);
    }

    function _record(id: string, line: string): void {
        const parts = line.split("|");
        if (parts.length < 2)
            return;
        const value = parts[0].trim();
        const tone = parts[1].trim();

        // The DETAIL field joins its lines with "//" (no spaces) and divides a
        // label from its value with " // " (spaces). Protect the spaced form,
        // split the lines, then read each one back as a { label, value } pair
        // or a { text } sentence. This is what lets the detail view lay figures
        // out one per row instead of dumping a flat list.
        const SENT = "\u0001";
        const rows = (parts[2] ?? "").replace(/ \/\/ /g, SENT).split("//").map(seg => {
            const s = seg.trim();
            if (s === "")
                return null;
            const bits = s.split(SENT);
            if (bits.length === 2)
                return { label: bits[0].trim(), value: bits[1].trim() };
            return { text: bits.join(" ").trim() };
        }).filter(r => r !== null);

        const next = Object.assign({}, readings);
        next[id] = {
            value: value,
            tone: tone,
            rows: rows,
            // Kept for anything still reading the flat form.
            detail: rows.map(r => r.value !== undefined ? `${r.label} // ${r.value}` : r.text)
        };
        readings = next;

        if (id === "ping") {
            const ms = parseFloat(value);
            if (isFinite(ms)) {
                const hist = pingHistory.slice();
                hist.push(ms);
                while (hist.length > 24)
                    hist.shift();
                pingHistory = hist;
            }
        }
    }

    FileView {
        id: file

        path: `${Paths.configDir}/daemons`
        watchChanges: true
        printErrors: false

        onLoaded: {
            for (const line of text().split("\n")) {
                const split = line.indexOf("=");
                if (split < 0)
                    continue;
                const key = line.slice(0, split).trim();
                const value = line.slice(split + 1).trim();
                if (key === "selected" && value) {
                    // **Deduplicated.** A hand-edited `selected=ping,ping,...`
                    // gave five identical rows on the HUD and five identical
                    // probes behind them -- five processes talking to the
                    // other side of the world for one reading.
                    const seen = {};
                    const ids = value.split(",").map(s => s.trim()).filter(s => {
                        if (root.entry(s) === null || seen[s])
                            return false;
                        seen[s] = true;
                        return true;
                    });
                    if (ids.length)
                        root.selected = ids.slice(0, root.maxSelected);
                } else if (key === "ping" && value) {
                    root.pingTarget = value;
                }
            }
        }
        onFileChanged: reload()
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root._save();
        }
    }

    // One process per selected daemon, polled only while the deck is up. The
    // probes are cheap, but PING talks to the other side of the world and there
    // is nothing to read when the panel is hidden.
    Instantiator {
        model: root.selected

        delegate: Scope {
            id: slot

            required property var modelData

            Process {
                id: probe

                // Absolute, not on the PATH: the shell is started by
                // Hyprland at login and ~/.local/bin is not on the PATH it
                // inherits -- the process simply failed to start.
                command: slot.modelData === "ping" ? [Paths.daemonScript, "ping", root.pingTarget] : [Paths.daemonScript, slot.modelData]
                stdout: StdioCollector {
                    onStreamFinished: root._record(slot.modelData, text.trim())
                }
            }

            Timer {
                // PING is slow and remote; the rest are local reads.
                interval: slot.modelData === "ping" ? 10000 : 5000
                running: ShellState.deckVisible
                repeat: true
                triggeredOnStart: true
                // Never stacked: a probe that has not finished is left alone
                // rather than started again beside itself.
                onTriggered: if (!probe.running) probe.running = true
            }
        }
    }
}
