pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Airplane mode and NetworkManager's VPN connections, for the Wi-Fi dropdown
// and the bar's tunnel lock.
//
// **Nothing polls.** Two event streams, idle until something changes: `rfkill
// event` (a radio blocked or unblocked, by anyone) and `nmcli monitor` (a
// connection coming up or going down). Each change re-reads the state once.
//
// Airplane mode is every radio soft-blocked (`rfkill block all`), so Wi-Fi,
// Bluetooth and mobile broadband are all off, and unblocking brings them back.
//
// `simulate` swaps in a made-up backend for tests: toggles then change only
// this state, never a radio or a tunnel.
Singleton {
    id: root

    property bool airplane: false
    // [{ name, type, up }]
    property var vpns: []
    readonly property bool tunnelUp: vpns.some(v => v.up)
    property string busy: ""        // the VPN being brought up or down

    property bool simulating: false

    function refresh(): void {
        if (simulating)
            return;
        if (!rfkillRead.running)
            rfkillRead.running = true;
        if (!vpnRead.running)
            vpnRead.running = true;
    }
    Component.onCompleted: refresh()

    function setAirplane(on: bool): void {
        if (simulating) {
            airplane = on;
            return;
        }
        runner.exec(["rfkill", on ? "block" : "unblock", "all"]);
    }
    function setVpn(name: string, up: bool): void {
        if (simulating) {
            vpns = vpns.map(v => v.name === name ? Object.assign({}, v, { up: up }) : v);
            return;
        }
        busy = name;
        runner.exec(["nmcli", "connection", up ? "up" : "down", "id", name]);
    }
    Process {
        id: runner
        onExited: {
            root.busy = "";
            root.refresh();
        }
    }

    // --- Reading ---------------------------------------------------------------
    Process {
        id: rfkillRead

        command: ["rfkill", "-J"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text)["rfkilldevices"] ?? [];
                    root.airplane = d.length > 0 && d.every(r => r.soft === "blocked");
                } catch (e) {}
            }
        }
    }
    Process {
        id: vpnRead

        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    // Terse output escapes colons inside names as `\:`.
                    const f = line.split(/(?<!\\):/).map(s => s.replace(/\\:/g, ":"));
                    if (f.length < 3)
                        continue;
                    const type = f[f.length - 2];
                    if (type !== "vpn" && type !== "wireguard")
                        continue;
                    out.push({ name: f.slice(0, -2).join(":"), type: type === "vpn" ? "OPENVPN / VPN" : "WIREGUARD", up: f[f.length - 1] === "yes" });
                }
                root.vpns = out;
            }
        }
    }

    // The event streams, restarted if they ever end.
    Process {
        running: !root.simulating
        command: ["rfkill", "event"]
        stdout: SplitParser {
            onRead: settle.restart()
        }
    }
    Process {
        running: !root.simulating
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: settle.restart()
        }
    }
    // A burst of events (a radio going down reports several) reads once.
    Timer {
        id: settle
        interval: 300
        onTriggered: root.refresh()
    }

    function simulate(on: bool): void {
        simulating = on;
        if (on) {
            airplane = false;
            vpns = [{ name: "Office", type: "WIREGUARD", up: false }, { name: "Home relay", type: "OPENVPN / VPN", up: false }];
        } else {
            refresh();
        }
    }
}
