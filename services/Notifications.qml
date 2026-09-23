pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import qs.config
import qs.services

// The shell's notification daemon. Only one can own the bus at a time, so
// Caelestia has to be stopped before this takes over.
//
// Each card is its own layer surface rather than one surface holding a column:
// the `wrayth-notifications` blur rule ignores alpha, so a single surface
// would frost the 12 px gaps between cards as well as the cards.
Singleton {
    id: root

    readonly property int maxVisible: 4
    readonly property int gap: 12

    // Newest first.
    //
    // **Demo mode filters rather than discards.** A recording should carry
    // only the notifications the script asked for, but a real one arriving
    // mid-take must not be thrown away -- the user is at the machine and it
    // might matter. Anything not raised by `sendDemo` stays tracked and
    // simply does not draw; the moment demo mode ends it appears like any
    // other card, with its own full lifetime.
    readonly property var list: {
        const tracked = server.trackedNotifications?.values ?? [];
        const visible = Demo.active ? tracked.filter(entry => root.demoIds.indexOf(entry.id) >= 0) : tracked;
        return visible.slice().reverse().slice(0, maxVisible);
    }

    // The ids `sendDemo` raised. It is a list rather than a flag because more
    // than one can be on screen at once.
    property var demoIds: []
    // True for the moment between spawning `notify-send` and the server
    // handing the notification back, which is how a card is known to be ours.
    // Nothing else in the shell sends while a recording is running.
    property bool expecting: false

    Timer {
        id: expectWindow

        interval: 2000
        onTriggered: root.expecting = false
    }

    // Card heights by notification id, published by the windows so each one
    // knows how far down the stack it sits.
    property var heights: ({})

    function setHeight(id: int, value: real): void {
        if (heights[id] === value)
            return;
        const next = Object.assign({}, heights);
        next[id] = value;
        heights = next;
    }

    // **Nothing ever removed an entry.** One key per notification, kept for
    // the life of the session: small, unbounded, and exactly what a leak
    // check is for. The map is pruned to the ids actually tracked whenever
    // the list changes -- a card's height is only ever asked for while its
    // card is on screen.
    function _prune(): void {
        const live = {};
        for (const entry of server.trackedNotifications?.values ?? [])
            live[entry.id] = true;
        const next = {};
        let dropped = false;
        for (const key of Object.keys(root.heights)) {
            if (live[key])
                next[key] = root.heights[key];
            else
                dropped = true;
        }
        if (dropped)
            root.heights = next;
    }

    onListChanged: Qt.callLater(root._prune)

    // The top of card `index`, measured from the top of the stack.
    function offsetOf(index: int): real {
        let y = 0;
        for (let i = 0; i < index && i < list.length; i++)
            y += (heights[list[i].id] ?? 0) + gap;
        return y;
    }

    function levelOf(notification: var): string {
        switch (notification?.urgency) {
        case NotificationUrgency.Critical:
            return "CRITICAL";
        case NotificationUrgency.Low:
            return "LOW";
        default:
            return "NORMAL";
        }
    }

    NotificationServer {
        id: server

        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        // Notifications are transient; a reload should not resurrect them.
        keepOnReload: false

        onNotification: notification => {
            notification.tracked = true;

            if (root.expecting) {
                root.expecting = false;
                expectWindow.stop();
                root.demoIds = root.demoIds.concat([notification.id]);
            }

            // Anything past the cap goes, oldest first, so the stack stays four
            // deep rather than quietly growing off screen.
            //
            // **The cap counts what is drawn.** Under demo mode the held
            // notifications are tracked but invisible, and counting them here
            // would dismiss the very cards the recording is waiting on.
            const tracked = server.trackedNotifications?.values ?? [];
            const counted = Demo.active ? tracked.filter(entry => root.demoIds.indexOf(entry.id) >= 0) : tracked;
            for (let i = 0; i < counted.length - root.maxVisible; i++)
                counted[i].dismiss();
        }
    }

    // The shell raising a notification of its own, used when an action fails
    // with an error the element itself has no room to show. It goes out over
    // D-Bus like anyone else's rather than being injected into the model
    // directly: wrayth owns `org.freedesktop.Notifications`, so it comes
    // straight back to the server above and takes the ordinary card, timer and
    // dismiss behaviour with no special case.
    function send(summary: string, body: string): void {
        notifier.exec(["notify-send", "-a", "wrayth", "-u", "normal", summary, body]);
    }

    // The same path, marked as the recording's own so `list` will draw it
    // while everything else is held. `app` is the name the card's `FROM`
    // line shows, so a scripted notification can look like it came from
    // wherever the scene needs it to.
    function sendDemo(summary: string, body: string, app: string, urgency: string): void {
        root.expecting = true;
        expectWindow.restart();
        notifier.exec(["notify-send", "-a", app || "wrayth", "-u", urgency || "normal", summary, body]);
    }

    // Held cards become visible again rather than being dropped.
    function releaseHeld(): void {
        root.demoIds = [];
    }

    Process {
        id: notifier
    }
}
