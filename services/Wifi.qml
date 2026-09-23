pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.config
import qs.services

// Wi-Fi for the UPLINK dropdown.
//
// The scan list, connecting and disconnecting all go through nmcli.
// Quickshell.Networking keeps the radio toggle and the answer to which network
// is actually up: its `networks` model only ever holds the connected one --
// `WifiDevice.scannerEnabled` is read-only and the module has no scan method --
// so the list and the connect path have to come from the same other source.
//
// Everything here runs only while the dropdown is on screen.
Singleton {
    id: root

    readonly property bool active: ShellState.dropdown === "wifi"
    readonly property bool radioOn: Networking.wifiEnabled

    readonly property var device: {
        for (const candidate of Networking.devices?.values ?? []) {
            if (candidate.name === Machine.wifiInterface)
                return candidate;
        }
        return null;
    }

    // --- What the bar's icon needs -----------------------------------------
    // **Live, and never polled.** `nmcli` is the source for the *list* of
    // networks, because Quickshell cannot see access points it is not
    // connected to -- but the one it *is* connected to carries its own
    // strength from NetworkManager, which is exactly and only what the bar
    // draws. Scanning on a timer to redraw four bars would be absurd.
    readonly property real strength: {
        for (const network of device?.networks?.values ?? []) {
            if (network.connected)
                return network.signalStrength;
        }
        return 0;
    }

    readonly property bool connected: root.activeSsid !== ""

    // A wired link lights every bar: the readout is "how good is the link",
    // and a cable is as good as it gets.
    readonly property bool wired: {
        for (const candidate of Networking.devices?.values ?? []) {
            if (candidate.type === DeviceType.Wired && candidate.connected)
                return true;
        }
        return false;
    }

    // The one thing Quickshell's model is reliable for.
    readonly property string activeSsid: {
        for (const network of device?.networks?.values ?? []) {
            if (network.connected)
                return network.name;
        }
        return "";
    }

    // Raw scan results: one entry per SSID, strongest reading kept.
    property var scanned: []
    // Names of saved connections, which is what makes a network "known".
    property var savedNames: []
    // The SSID a connect attempt is running for, so the row can say LINKING.
    property string linking: ""
    // The SSID of the last attempt, and why it failed, if it did. nmcli says
    // nothing on success and exits non-zero with a reason on failure, so the
    // exit code is what decides -- not whether the link came up a moment later.
    property string attempted: ""
    property string error: ""
    // nmcli's own words, kept for the notification an action raises when it
    // fails. `error` is the few words the dropdown has room for; this is the
    // sentence behind them.
    property string errorDetail: ""

    // Raised when any nmcli action finishes, so the buttons can resolve their
    // working state. `linking` falling to "" only covers connects -- a
    // disconnect or a forget never set it -- so watching this is what lets one
    // handler serve every action in the dropdown.
    signal actionFinished(bool ok, string reason, string detail)

    function clearError(): void {
        error = "";
    }

    // nmcli's failures are sentences. The dropdown has room for a few words.
    function describe(message: string): string {
        const text = message.toLowerCase();
        if (text.includes("secrets were required") || text.includes("802.1x supplicant") || text.includes("incorrect"))
            return "BAD PASSPHRASE";
        if (text.includes("no network with ssid") || text.includes("not found"))
            return "NETWORK GONE";
        if (text.includes("timeout") || text.includes("timed out"))
            return "TIMED OUT";
        return "LINK FAILED";
    }

    property string band: ""
    property bool scanning: false

    // --- The connected network's own settings, for the settings view --------
    // The security of the in-use network (WPA2, WPA3, 802.1X, or "OPEN"), read
    // from the same scan the list comes from.
    property string activeSecurity: ""
    // The active wifi connection profile, and the three properties the settings
    // view lets the user change. All are read back from NetworkManager, never
    // assumed, so a toggle reflects what actually took.
    property string activeConnName: ""
    property bool autoconnect: true
    property bool metered: false
    property bool randomMac: false

    readonly property var networks: {
        const saved = savedNames;
        const live = activeSsid;
        const busy = linking;
        const failed = error !== "" ? attempted : "";
        const list = scanned.map(entry => ({
            ssid: entry.ssid,
            signal: entry.signal,
            secured: entry.secured,
            known: saved.indexOf(entry.ssid) >= 0,
            connected: entry.ssid === live,
            linking: entry.ssid === busy,
            failed: entry.ssid === failed
        }));
        // Connected first, then by strength.
        list.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            return b.signal - a.signal;
        });
        // **`label` is what a row draws; `ssid` is what nmcli is handed.**
        // Demo mode masks the neighbours' network names for a recording, and
        // keeping the two apart means a masked list can still be acted on --
        // and, more to the point, that a mask can never be typed at nmcli.
        // Numbered after the sort, so the names do not shuffle frame to frame.
        return list.map((entry, index) => Object.assign({}, entry, {
                    label: Demo.ssidAt(entry.ssid, index, entry.connected)
                }));
    }

    readonly property int inRange: networks.length

    // nmcli's terse output separates fields with ":" and backslash-escapes any
    // that appear inside a value, so it cannot just be split.
    function splitTerse(line: string): var {
        const fields = [];
        let field = "";
        for (let i = 0; i < line.length; i++) {
            const c = line[i];
            if (c === "\\" && i + 1 < line.length)
                field += line[++i];
            else if (c === ":")
                {
                    fields.push(field);
                    field = "";
                }
            else
                field += c;
        }
        fields.push(field);
        return fields;
    }

    function refresh(): void {
        if (!radioOn) {
            scanned = [];
            return;
        }
        savedProc.running = true;
        listProc.running = true;
        bandProc.running = true;
        activeConnProc.running = true;
    }

    function rescan(): void {
        if (scanning || !radioOn)
            return;
        scanning = true;
        rescanProc.running = true;
    }

    // The passphrase for the running connect attempt, written to nmcli's stdin
    // in connectProc.onStarted and cleared the instant it is written. It is
    // **never** an argv element -- see connectWithPsk. "" means nothing to send.
    property string _pendingSecret: ""

    // A known network (stored secret) or an open one: no passphrase to hide, so
    // nmcli needs no prompt and no stdin.
    function connect(ssid: string): void {
        begin(ssid);
        root._pendingSecret = "";
        connectProc.stdinEnabled = false;
        connectProc.command = ["nmcli", "device", "wifi", "connect", ssid, "ifname", Machine.wifiInterface];
        connectProc.running = true;
    }

    // **The passphrase goes to nmcli on stdin, never as an argument.** A
    // `password <psk>` argv element sits in /proc/<pid>/cmdline, world-readable
    // for as long as nmcli runs, so any local user could read the secret of a
    // network being joined. Instead `--ask` makes nmcli prompt for the one
    // missing secret (the AP is secured and no password was given) and read it
    // from stdin; `_pendingSecret` is written in connectProc.onStarted and the
    // pipe is then closed. Verified: the psk never appears in the process argv.
    function connectWithPsk(ssid: string, psk: string): void {
        begin(ssid);
        root._pendingSecret = psk;
        connectProc.stdinEnabled = true;
        connectProc.command = ["nmcli", "--ask", "device", "wifi", "connect", ssid, "ifname", Machine.wifiInterface];
        connectProc.running = true;
    }

    function begin(ssid: string): void {
        linking = ssid;
        attempted = ssid;
        error = "";
    }

    function disconnect(): void {
        error = "";
        root._pendingSecret = "";
        connectProc.stdinEnabled = false;
        connectProc.command = ["nmcli", "device", "disconnect", Machine.wifiInterface];
        connectProc.running = true;
    }

    // Delete the saved connection, so the network stops being "known" and asks
    // for its passphrase again. Its own process rather than `connectProc`:
    // that one's exit code drives the linking state machine, and a forget is
    // not a link attempt.
    function forget(ssid: string): void {
        error = "";
        forgetProc.command = ["nmcli", "connection", "delete", "id", ssid];
        forgetProc.running = true;
    }

    // Opens the network's own settings. `nm-connection-editor` if it is
    // installed, otherwise `nmtui-edit` in a terminal -- this machine has
    // nmtui and not the editor, and neither is worth making a dependency.
    function openSettings(ssid: string): void {
        Deck.launch(["sh", "-c", `command -v nm-connection-editor >/dev/null && exec nm-connection-editor || exec kitty --class wr-net-settings nmtui-edit '${ssid.replace(/'/g, "'\\''")}'`]);
    }

    // Join a network that does not broadcast its name. Runs through the same
    // connect state machine as an ordinary join.
    function joinHidden(ssid: string, psk: string): void {
        if (ssid === "")
            return;
        begin(ssid);
        // Same argv-free rule as connectWithPsk: a passphrase is fed on stdin
        // via `--ask`, never on the command line. An open hidden network needs
        // no secret and takes the plain path.
        root._pendingSecret = psk;
        connectProc.stdinEnabled = psk !== "";
        connectProc.command = (psk !== ""
            ? ["nmcli", "--ask", "device", "wifi", "connect", ssid]
            : ["nmcli", "device", "wifi", "connect", ssid])
            .concat(["ifname", Machine.wifiInterface, "hidden", "yes"]);
        connectProc.running = true;
    }

    // The connected profile's three switches. Each writes through nmcli and then
    // re-reads, so the toggle settles on what NetworkManager actually holds.
    function _modify(key: string, value: string): void {
        if (activeConnName === "")
            return;
        modifyProc.command = ["nmcli", "connection", "modify", activeConnName, key, value];
        modifyProc.running = true;
    }

    function setAutoconnect(on: bool): void {
        root._modify("connection.autoconnect", on ? "yes" : "no");
    }

    function setMetered(on: bool): void {
        root._modify("connection.metered", on ? "yes" : "no");
    }

    function setRandomMac(on: bool): void {
        root._modify("802-11-wireless.cloned-mac-address", on ? "random" : "permanent");
    }

    Process {
        id: forgetProc

        // The saved list is what decides whether a network is "known", so it
        // has to be re-read the moment one is deleted.
        onExited: root.refresh()
    }

    // The active wifi connection's profile name, so its properties can be read
    // and written by name.
    Process {
        id: activeConnProc

        command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show", "--active"]

        stdout: StdioCollector {
            onStreamFinished: {
                let name = "";
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    const fields = root.splitTerse(line);
                    if (fields.length < 3)
                        continue;
                    const device = fields[fields.length - 1];
                    const type = fields[fields.length - 2];
                    if (type !== "802-11-wireless")
                        continue;
                    name = fields.slice(0, -2).join(":");
                    if (device === Machine.wifiInterface)
                        break;
                }
                root.activeConnName = name;
                if (name !== "") {
                    propsProc.command = ["nmcli", "-t", "-f", "connection.autoconnect,connection.metered,802-11-wireless.cloned-mac-address", "connection", "show", name];
                    propsProc.running = true;
                } else {
                    root.autoconnect = true;
                    root.metered = false;
                    root.randomMac = false;
                }
            }
        }
    }

    Process {
        id: propsProc

        stdout: StdioCollector {
            onStreamFinished: {
                for (const line of text.split("\n")) {
                    const idx = line.indexOf(":");
                    if (idx < 0)
                        continue;
                    const key = line.slice(0, idx);
                    const value = line.slice(idx + 1).trim();
                    if (key === "connection.autoconnect")
                        root.autoconnect = value === "yes";
                    else if (key === "connection.metered")
                        root.metered = value === "yes";
                    else if (key === "802-11-wireless.cloned-mac-address")
                        root.randomMac = value.toLowerCase() === "random";
                }
            }
        }
    }

    Process {
        id: modifyProc

        onExited: root.refresh()
    }

    onRadioOnChanged: {
        if (!radioOn)
            scanned = [];
    }

    // A failure is about one visit to the dropdown, not the session.
    onActiveChanged: {
        if (!active) {
            error = "";
            attempted = "";
        }
    }

    // --- Processes ---------------------------------------------------------

    Process {
        id: listProc

        // The default --rescan auto is the point: --rescan no returns whatever
        // NetworkManager last cached, which while connected is often just the
        // one access point in use.
        command: ["nmcli", "-t", "-f", "IN-USE,SIGNAL,SECURITY,SSID", "device", "wifi", "list"]

        stdout: StdioCollector {
            onStreamFinished: {
                // One row per access point, so several per network. Keep the
                // strongest reading of each name and drop hidden ones.
                const best = {};
                let activeSec = "";
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    const fields = root.splitTerse(line);
                    if (fields.length < 4)
                        continue;
                    const ssid = fields.slice(3).join(":");
                    if (!ssid)
                        continue;
                    const signal = parseInt(fields[1]) || 0;
                    const security = fields[2].trim();
                    // The in-use row (IN-USE = "*") carries the security the
                    // settings view names for the connected network.
                    if (fields[0].trim() === "*")
                        activeSec = security !== "" && security !== "--" ? security : "OPEN";
                    if (best[ssid] !== undefined && best[ssid].signal >= signal)
                        continue;
                    best[ssid] = {
                        ssid: ssid,
                        signal: signal,
                        secured: security !== "" && security !== "--"
                    };
                }
                root.scanned = Object.keys(best).map(key => best[key]);
                root.activeSecurity = activeSec;
            }
        }
    }

    Process {
        id: savedProc

        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection", "show"]

        stdout: StdioCollector {
            onStreamFinished: {
                const names = [];
                for (const line of text.split("\n")) {
                    if (!line)
                        continue;
                    const fields = root.splitTerse(line);
                    if (fields[fields.length - 1] === "802-11-wireless")
                        names.push(fields.slice(0, -1).join(":"));
                }
                root.savedNames = names;
            }
        }
    }

    Process {
        id: connectProc

        stderr: StdioCollector {
            id: connectError

        }

        // Feed the passphrase (when there is one) to nmcli's `--ask` prompt on
        // stdin, then close the write end so nmcli reads the one line and never
        // blocks waiting for more. The pipe carried the secret in place of argv,
        // so it never reached /proc.
        onStarted: {
            if (root._pendingSecret !== "")
                connectProc.write(root._pendingSecret + "\n");
            root._pendingSecret = "";
            connectProc.stdinEnabled = false;
        }

        // The reason is set before `linking` clears, so anything watching
        // `linking` fall to "" already sees whether it worked.
        onExited: exitCode => {
            const ok = exitCode === 0;
            root.error = ok ? "" : root.describe(connectError.text);
            root.errorDetail = ok ? "" : connectError.text.trim();
            root.linking = "";
            root._pendingSecret = "";
            root.refresh();
            root.actionFinished(ok, root.error, root.errorDetail);
        }
    }

    Process {
        id: rescanProc

        command: ["nmcli", "device", "wifi", "rescan"]
        onExited: {
            root.scanning = false;
            root.refresh();
        }
    }

    Process {
        id: bandProc

        // The in-use row's frequency, in MHz.
        command: ["sh", "-c", "nmcli -t -f IN-USE,FREQ device wifi | awk -F: '/^\\*/ {print $2; exit}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const mhz = parseInt(text.trim());
                if (!isFinite(mhz) || mhz <= 0)
                    root.band = "";
                else if (mhz >= 5925)
                    root.band = "6 GHZ";
                else if (mhz >= 4900)
                    root.band = "5 GHZ";
                else
                    root.band = "2.4 GHZ";
            }
        }
    }

    // Only runs while the dropdown is on screen. triggeredOnStart carries the
    // first scan: this singleton is not constructed until something binds to
    // it, which is the dropdown opening, so by the time it exists `active` is
    // already true and an onActiveChanged handler would never fire.
    Timer {
        interval: 15000
        running: root.active && root.radioOn
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }
}
