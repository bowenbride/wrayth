import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// **State the minimum once, then be quiet.** wrayth's deck is laid out for
// 1920x1080 and clips gracefully below that (see the README): on a screen under
// 850px tall the SYS.DIAG daemon list is trimmed to fit. Everything still works
// -- this only tells the user, and only once. The marker file's mere existence
// is the "already told you" flag, so the notice is shown a single time rather
// than on every login; delete it (or the state dir) to see it again. A screen
// that is tall enough writes no marker, so attaching a short one later still
// warns.
Scope {
    id: root

    // True once the marker has been read (already notified) or written (just
    // notified). Until the marker's load resolves, nothing is decided.
    property bool settled: false

    function evaluate(): void {
        if (root.settled)
            return;
        for (const s of ShellState.screens) {
            if (s && s.height > 0 && s.height < 850) {
                Notifications.send("Wrayth: short screen", `This screen is ${s.height}px tall. The deck is designed for 1920x1080 and is clipped to fit below ~850px -- everything still works. See the README.`);
                marker.setText("shown\n");
                root.settled = true;
                return;
            }
        }
    }

    // The marker is read first. If it exists the notice was already shown, so
    // settle and stay quiet; if it does not, evaluate the screens once.
    FileView {
        id: marker

        path: Paths.shortScreenFlag
        printErrors: false

        onLoaded: root.settled = true
        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.evaluate();
        }
    }
}
