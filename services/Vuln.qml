pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// arch-audit, for the vuln watch panel and the bar ticker's count.
Singleton {
    id: root

    // { name, severity, fixed, fixedVersion, type, shortType, cves: [], cveCount, group }
    property var packages: []
    readonly property int count: packages.length

    readonly property int high: _countOf("HIGH")
    readonly property int medium: _countOf("MED")
    readonly property int low: _countOf("LOW")

    // The two groups the panel lists under, rather than a status word repeated
    // on every row. Anything arch-audit gives a fixed version for is already
    // fixed in the repos and only needs the upgrade running.
    readonly property var fixReady: packages.filter(entry => entry.fixed)
    readonly property var awaiting: packages.filter(entry => !entry.fixed)

    property real lastSync: 0
    property int syncedMinutes: 0
    readonly property bool synced: lastSync > 0
    property bool scanning: false

    // **Whether arch-audit is there at all.** A process that cannot start
    // emits neither `exited` nor `streamFinished` -- only `running` falling
    // back to false -- so a missing tool used to leave `scanning` true for
    // the rest of the session, which made every later `refresh()` return at
    // its own guard and killed the hourly sweep with it. Measured against a
    // deliberately absent binary.
    //
    // It also changes what the panel may claim: an audit that never ran is
    // not the same news as an audit that found nothing.
    property bool available: true

    // Re-run the audit. Called after an upgrade, so the panel reflects what the
    // upgrade actually fixed rather than what was true before it.
    function refresh(): void {
        if (scanning)
            return;
        scanning = true;
        _answered = false;
        auditProc.running = true;
    }

    // The system upgrade. It needs a password, so it has to be a terminal the
    // user can type into rather than anything the shell runs itself; the audit
    // is re-run when it exits so the panel shows what the upgrade actually
    // fixed. One at a time: this upgrades the whole system, so the button is on
    // a row only because that is where a fix is noticed.
    property bool upgrading: false

    signal upgradeFinished(bool ok)

    function upgrade(): void {
        if (upgrading)
            return;
        upgrading = true;
        // The upgrade terminal opens on the desktop, not in the deck it was
        // started from. A Process rather than Deck.launch: its exit code is
        // the upgrade's result.
        Deck.leave();
        upgradeProc.running = true;
    }

    // Set by the collector, cleared before each run: it is the one thing
    // that says the tool actually ran, whatever it then found.
    property bool _answered: false

    Process {
        id: upgradeProc

        // `exit $rc` so pacman's own result survives the pause that keeps the
        // window up long enough to read what it did.
        command: ["kitty", "--class", "wrayth-upgrade", "-e", "bash", "-lc", "sudo pacman -Syu; rc=$?; echo; read -n 1 -s -r -p 'Upgrade finished. Press any key to close.'; exit $rc"]

        onExited: exitCode => {
            root.upgradeFinished(exitCode === 0);
            root.refresh();
        }

        // Covers the exit above **and** a terminal that could not be started
        // at all, which emits nothing else.
        onRunningChanged: if (!running) root.upgrading = false
    }

    // The tracker's page for a package, which is what OPEN ADVISORY opens.
    // Removes a package in a terminal, because pacman needs a password the
    // shell must not ask for -- and pacman's own confirmation is the
    // confirmation. `-Rns` takes its dependencies too, which is why REMOVE is
    // only offered when nothing requires the package.
    function remove(name: string): void {
        // The package name is a positional arg (`"$1"`), never interpolated
        // into the shell string: it comes from arch-audit's output, and a
        // hostile package name in the database must not be able to run as a
        // command. -- takes no more options after it.
        Deck.launch(["kitty", "--class", "wrayth-remove", "-e", "bash", "-lc", "sudo pacman -Rns -- \"$1\"; rc=$?; echo; read -n 1 -s -r -p 'Removal finished. Press any key to close.'; exit $rc", "bash", name]);
    }

    function advisoryUrl(name: string): string {
        return `https://security.archlinux.org/package/${name}`;
    }

    function _updateAge(): void {
        syncedMinutes = lastSync > 0 ? Math.floor((Date.now() - lastSync) / 60000) : 0;
    }

    function _countOf(severity: string): int {
        return packages.filter(entry => entry.severity === severity).length;
    }

    // Arch's tracker uses Critical/High/Medium/Low; the spec folds Critical into HIGH.
    function _severity(raw: string): string {
        const text = raw.toLowerCase();
        if (text.startsWith("critical") || text.startsWith("high"))
            return "HIGH";
        if (text.startsWith("medium"))
            return "MED";
        return "LOW";
    }

    // arch-audit's type field is a lowercase phrase, and often several of them
    // comma-separated ("unknown, denial of service"). The row has space for a
    // few characters, so each phrase maps to a short tag and the most serious
    // one wins; the expanded row shows the original text in full.
    //
    // Ordered worst first, so the first match is also the one to show.
    readonly property var _types: [
        ["arbitrary code execution", "CODE EXEC"],
        ["arbitrary command execution", "CODE EXEC"],
        ["privilege escalation", "PRIV ESC"],
        ["sandbox escape", "SANDBOX ESCAPE"],
        ["authentication bypass", "AUTH BYPASS"],
        ["certificate verification bypass", "CERT BYPASS"],
        ["signature forgery", "SIG FORGERY"],
        ["arbitrary filesystem access", "FS ACCESS"],
        ["arbitrary file write", "FILE WRITE"],
        ["arbitrary file overwrite", "FILE WRITE"],
        ["arbitrary file read", "FILE READ"],
        ["directory traversal", "PATH TRAVERSAL"],
        ["sql injection", "SQL INJECTION"],
        ["xml external entity injection", "XXE"],
        ["cross-site scripting", "XSS"],
        ["cross-site request forgery", "CSRF"],
        ["url request injection", "REQ INJECTION"],
        ["content spoofing", "SPOOFING"],
        ["session hijacking", "SESSION HIJACK"],
        ["man-in-the-middle", "MITM"],
        ["open redirect", "OPEN REDIRECT"],
        ["use after free", "USE AFTER FREE"],
        ["buffer overflow", "BUFFER OVERFLOW"],
        ["integer overflow", "INT OVERFLOW"],
        ["race condition", "RACE"],
        ["time of check to time of use", "TOCTOU"],
        ["insufficient validation", "BAD VALIDATION"],
        ["information disclosure", "INFO LEAK"],
        ["denial of service", "DENIAL OF SERVICE"],
        ["multiple issues", "MULTIPLE"],
        ["unknown", "UNKNOWN"]
    ]

    function _shortType(raw: string): string {
        const text = (raw ?? "").toLowerCase();
        if (!text)
            return "UNKNOWN";
        for (const [phrase, tag] of _types) {
            if (text.includes(phrase))
                return tag;
        }
        // Something the tracker added that is not in the table yet: show it
        // rather than calling it unknown, trimmed to the first phrase.
        return text.split(",")[0].trim().toUpperCase();
    }

    Process {
        id: auditProc

        // %n name, %c CVEs, %v fixed version, %t type, %s severity.
        command: ["arch-audit", "-f", "%n|%c|%v|%t|%s"]
        stdout: StdioCollector {
            onStreamFinished: {
                const entries = [];
                for (const line of text.split("\n")) {
                    if (!line.trim())
                        continue;
                    const parts = line.split("|");
                    const cves = (parts[1] ?? "").split(",").map(cve => cve.trim()).filter(cve => cve);
                    const type = (parts[3] ?? "").trim();
                    // arch-audit only fills the version column when an upgrade
                    // in the repos fixes the issue.
                    const fixed = !!(parts[2] ?? "").trim();
                    entries.push({
                        name: parts[0],
                        severity: root._severity(parts[4] ?? ""),
                        fixed,
                        fixedVersion: (parts[2] ?? "").trim(),
                        type,
                        shortType: root._shortType(type),
                        cves,
                        cveCount: cves.length,
                        group: fixed ? "FIX READY" : "AWAITING UPSTREAM"
                    });
                }
                // Fixed first, so the section that can be acted on is on top,
                // then worst first inside each section. The comparator gives a
                // total order rather than returning 0 for ties: QML's JS engine
                // does not promise a stable sort, and a comparator that only
                // ranked `fixed` scrambled arch-audit's own severity ordering.
                const rank = {
                    HIGH: 0,
                    MED: 1,
                    LOW: 2
                };
                entries.sort((a, b) => {
                    if (a.fixed !== b.fixed)
                        return a.fixed ? -1 : 1;
                    if (rank[a.severity] !== rank[b.severity])
                        return rank[a.severity] - rank[b.severity];
                    return a.name.localeCompare(b.name);
                });
                root.packages = entries;
                root._answered = true;
                root.lastSync = Date.now();
                root._updateAge();
            }
        }

        // Whatever happened -- a clean run, a non-zero exit, or a binary that
        // is not installed and never started. `available` is decided here
        // rather than in the collector, because the collector is exactly what
        // does not run when the tool is missing.
        onRunningChanged: {
            if (running)
                return;
            // The collector never ran, so neither did arch-audit.
            root.available = root._answered;
            root.scanning = false;
        }
    }

    Timer {
        interval: 60 * 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root._updateAge()
    }
}
