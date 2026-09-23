pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.config

// Host status the bar ticker reads, and the HUD and lockscreen will reuse.
// These poll continuously rather than only while the deck is up, because the
// bar ticker shows them all the time.
Singleton {
    id: root

    // ICE: failed systemd units.
    property int failedUnits: 0
    readonly property bool breach: failedUnits > 0

    // PKG: pending package updates.
    property int pendingUpdates: 0

    // SHIELD: which host firewall is running, if any. Tri-state on purpose --
    // an unprotected machine ("down") and one we simply cannot read ("unknown")
    // must never look the same, so a failed or permission-denied check reports
    // UNKNOWN, never DOWN. Detection is rootless: it asks systemd whether any of
    // the four firewall units is active, which needs no privileges (unlike
    // `ufw status` or `nft list ruleset`, which do and would fail silently here).
    property string shieldState: "unknown"   // "armed" | "down" | "unknown"
    property string shieldFirewall: ""        // e.g. "ufw", when armed
    readonly property bool shieldArmed: shieldState === "armed"

    // PING: round trip to the default gateway in ms, or -1 when there is no
    // route or it does not answer. **Deliberately the local gateway, not an
    // internet host.** An earlier version pinged 1.1.1.1 (Cloudflare) every ten
    // seconds for the whole session, which is a standing outbound heartbeat to
    // an outside service that the user never opted into. The gateway is on the
    // local link, so this contacts nothing beyond the router and still answers
    // "is the connection up, and how quick is the first hop". Reaching an
    // actual internet host is the deck's PING daemon, which is opt-in (the deck
    // must be open and the daemon selected) and lets the user pick the target.
    property real pingMs: -1
    readonly property bool uplinkDown: pingMs < 0

    // UPLINK: the SSID of the connected wifi network, empty when offline.
    readonly property string ssid: {
        const devices = Networking.devices?.values ?? [];
        for (const device of devices) {
            for (const network of device.networks?.values ?? []) {
                if (network.connected)
                    return network.name;
            }
        }
        return "";
    }

    Process {
        id: failedProc

        command: ["sh", "-c", "systemctl --failed --no-legend --plain | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: root.failedUnits = Number(text.trim()) || 0
        }
    }

    Process {
        id: updatesProc

        command: ["sh", "-c", "checkupdates | wc -l"]
        stdout: StdioCollector {
            onStreamFinished: root.pendingUpdates = Number(text.trim()) || 0
        }
    }

    Process {
        id: shieldProc

        // Prints "armed <unit>" for the first active firewall, "down" when all
        // four answered and none is active, or "unknown" when the query itself
        // could not run (no systemctl, D-Bus refused). `systemctl is-active`
        // needs no root. If the whole process yields nothing, the parser below
        // defaults to unknown -- a broken check is never read as DOWN.
        command: ["sh", "-c",
            "command -v systemctl >/dev/null 2>&1 || { echo unknown; exit 0; }; " +
            "answered=0; " +
            "for u in nftables iptables ufw firewalld; do " +
            "s=$(systemctl is-active \"$u\" 2>/dev/null); " +
            "[ \"$s\" = active ] && { echo \"armed $u\"; exit 0; }; " +
            "[ -n \"$s\" ] && answered=1; " +
            "done; " +
            "[ \"$answered\" = 1 ] && echo down || echo unknown"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.trim().split(/\s+/);
                const state = parts[0] || "unknown";
                if (state === "armed") {
                    root.shieldFirewall = parts[1] || "";
                    root.shieldState = "armed";
                } else if (state === "down") {
                    root.shieldFirewall = "";
                    root.shieldState = "down";
                } else {
                    root.shieldFirewall = "";
                    root.shieldState = "unknown";
                }
            }
        }
    }

    Process {
        id: pingProc

        command: ["sh", "-c", "gw=$(ip route show default 2>/dev/null | grep -oP 'via \\K[0-9.]+' | head -1); [ -n \"$gw\" ] && ping -c1 -W1 \"$gw\" | grep -oP 'time=\\K[0-9.]+'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const value = parseFloat(text.trim());
                root.pingMs = isFinite(value) ? value : -1;
            }
        }
    }

    // Intervals come from the spec's data source table.
    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: failedProc.running = true
    }

    Timer {
        interval: 30 * 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: updatesProc.running = true
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: shieldProc.running = true
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: pingProc.running = true
    }
}
