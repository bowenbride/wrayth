import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Writes ~/.cache/wrayth/status for the terminals' greeting line, so bash
// never has to run checkupdates or arch-audit itself.
//
// A plain component rather than a singleton: a singleton nothing binds to is
// never constructed, and nothing would bind to this one.
Scope {
    id: root

    // The first outstanding task, which is the one the planner marks ACTIVE.
    // **The masked label, not the name.** This file is what the deck
    // terminal's greeting reads, so an unmasked task name here would be
    // printed on camera by `wrayth-welcome`. The planner's own file still
    // holds the real one; this is a cache the shell rewrites constantly and
    // puts back the moment demo mode ends.
    readonly property string activeTask: (Planner.ordered.find(entry => !entry.done)?.label ?? "").replace(/'/g, "")

    // Every value the deck terminal's fetch and welcome message show comes from
    // here, so neither ever runs checkupdates, arch-audit or systemctl itself.
    // The deck terminal's fetch header. It is the one masked value that has
    // to leave the shell: `fastfetch`'s title module reads `{$WR_TITLE}`,
    // `_wrayth_fetch` exports it from here, and without this the recording
    // would carry `<user>@<hostname>` in 20 px type above the prompt.
    readonly property string fetchTitle: Demo.fetchTitle(Runner.user, Machine.hostname).replace(/'/g, "")

    // **The shell prompt's identity, for every terminal already open.** `\u`
    // and `\h` are bash's own escapes and cannot be overridden, so
    // `_wrayth_prompt` reads this and substitutes the strings -- and because
    // it reads on every prompt, a terminal open before the recording began
    // picks the masked identity up at its next line.
    readonly property string promptIdent: Demo.promptIdentity(Runner.user, Machine.hostname).replace(/[^A-Za-z0-9@._-]/g, "")

    readonly property string contents: `QUEUE_DONE=${Planner.done}
QUEUE_TOTAL=${Planner.total}
QUEUE_ACTIVE='${activeTask}'
VULN=${Vuln.count}
VULN_HIGH=${Vuln.high}
VULN_FIXABLE=${Vuln.fixReady.length}
ICE=${SystemStatus.failedUnits}
PKG=${SystemStatus.pendingUpdates}
SHIELD=${SystemStatus.shieldState === "armed" ? "ARMED" : SystemStatus.shieldState === "down" ? "DOWN" : "UNKNOWN"}
SHIELD_FW='${SystemStatus.shieldFirewall.replace(/['\n\r]/g, "")}'
PROFILE='${Theme.profile.replace(/['\n\r]/g, "")}'
FETCH_TITLE='${root.fetchTitle}'
HANDLE='${Demo.handle(Runner.handle).replace(/'/g, "")}'
PROMPT_IDENT='${root.promptIdent}'
`

    onContentsChanged: write.restart()

    // Coalesced: several of these counts land within a tick of each other.
    Timer {
        id: write

        interval: 250
        onTriggered: file.setText(root.contents)
    }

    FileView {
        id: file

        path: Paths.statusFile
        printErrors: false
    }

    Component.onCompleted: file.setText(contents)
}
