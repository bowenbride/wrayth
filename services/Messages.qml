pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.config
import qs.services

// Whether there are unread messages, and nothing else.
//
// **The shell never reads a message.** One bit -- "something unread" -- taken
// from the chat client's own tray icon swapping to its badged image. No
// content, no counts, nothing written to disk, and the client's artwork is
// never drawn: the bar has its own glyph.
//
// Two halves, for one reason each:
//
//   `SystemTray` is bound because **Quickshell's tray service is itself the
//   `StatusNotifierWatcher`**, and without a watcher on the bus the client
//   publishes no item at all -- measured: an empty
//   `RegisteredStatusNotifierItems` and no matching bus name, until this was
//   bound. Discord re-registers on its own once the watcher appears.
//
//   `wrayth-unread` decides read from unread, because nothing cheaper
//   exists on this client: no `IconName`, an empty `AttentionIconName`, a
//   `Status` that stays `Active`, and no Unity `LauncherEntry` traffic at
//   all. Only the pixmap changes, and comparing pixmaps is not a thing to do
//   in QML. It subscribes to the item's `NewIcon`; it does not poll.
Singleton {
    id: root

    // "absent", "read" or "unread", straight from the helper.
    property string state: "absent"

    // Bus ids that are a chat client worth watching -- the same list the
    // helper uses, for the one thing this side needs it for.
    readonly property var wanted: ["discord", "vesktop", "webcord", "equibop"]

    // Reading this is what constructs the tray service, and constructing the
    // tray service is what puts a watcher on the bus. It is not decoration.
    readonly property var item: {
        const items = SystemTray.items?.values ?? [];
        for (const candidate of items) {
            const id = String(candidate.id ?? "").toLowerCase();
            if (root.wanted.some(name => id.includes(name)))
                return candidate;
        }
        return null;
    }

    // **The tray item is the authority on whether the client is there**, not
    // the helper's own `absent`: it is synchronous, it comes from the same
    // registration the helper reads, and it cannot get stuck if the helper
    // dies. The helper decides read from unread and nothing else.
    // **Demo mode forces the one bit and nothing else.** There is no content
    // here to fake, because there is no content anywhere in this file: the
    // shell still never reads a message, in demo mode or out of it.
    readonly property bool running: Demo.messagesForced || root.item !== null
    readonly property bool unread: Demo.messagesForced ? Demo.messagesUnread : root.state === "unread"

    // **It restarts.** `running: true` starts the helper once; a helper that
    // is killed or crashes then leaves the indicator frozen on whatever it
    // last said, with no way back but a shell restart. The backoff is what
    // keeps a helper that cannot run at all -- missing, not executable --
    // from becoming a spawn loop.
    Process {
        id: watcher

        command: [Paths.unreadScript, "--watch"]
        running: true

        stdout: SplitParser {
            onRead: line => {
                const value = line.trim();
                if (["absent", "read", "unread"].indexOf(value) >= 0)
                    root.state = value;
            }
        }

        // Covers an exit and a failure to start alike: a process that cannot
        // start emits no `exited` at all, only this.
        onRunningChanged: if (!running) revive.restart()
    }

    Timer {
        id: revive

        interval: 5000
        onTriggered: watcher.running = true
    }
}
