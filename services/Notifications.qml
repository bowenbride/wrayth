pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
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

    // --- COMMS: the history, Do Not Disturb, and the fullscreen hold ----------
    //
    // **The history lives in this process's memory and nowhere else.** It is
    // never written to disk, never sent anywhere, and it is gone when the
    // session ends (logout, or the shell restarting). Plain text only: summary
    // and body as the app sent them, the app's name, the time, the urgency.
    // Newest first, and capped, so a chatty app cannot grow it without bound.
    readonly property int historyLimit: 200
    property var history: []
    // Entries not yet read: the message indicator's dot. An entry is read when
    // it is opened from COMMS, when its app's window gains focus, or when the
    // app withdraws it; the dot clears on its own once nothing is unread.
    readonly property int unseen: history.filter(e => !e.seen).length
    // The live notification objects by entry key, while the server still has
    // them: what OPEN invokes, and how a withdrawal is heard.
    property var _objects: ({})
    property int _nextId: 1

    // In memory too: a new session starts with it off.
    property bool dnd: false

    function _remember(notification: var, held: bool): void {
        const key = root._nextId;
        const objs = Object.assign({}, root._objects);
        objs[key] = notification;
        root._objects = objs;
        // An app withdrawing its notification (it was read there) removes it.
        notification.closed.connect(reason => {
            if (reason === NotificationCloseReason.CloseRequested)
                root.remove(key);
            const o = Object.assign({}, root._objects);
            delete o[key];
            root._objects = o;
        });
        const entry = {
            key: root._nextId++,
            app: (notification.appName || "UNKNOWN").trim(),
            summary: notification.summary ?? "",
            body: notification.body ?? "",
            time: Date.now(),
            level: root.levelOf(notification),
            held: held,
            seen: false
        };
        root.history = [entry].concat(root.history).slice(0, root.historyLimit);
    }

    function markSeen(): void {
        if (unseen === 0)
            return;
        root.history = root.history.map(e => e.seen ? e : Object.assign({}, e, { seen: true }));
    }

    // Every card on screen dismissed, critical ones included.
    function dismissAll(): void {
        for (const n of (server.trackedNotifications?.values ?? []).slice())
            n.dismiss();
    }

    function clearHistory(): void {
        root.history = [];
    }

    function remove(key: int): void {
        root.history = root.history.filter(e => e.key !== key);
    }

    // Every notification of an app read: its window has the focus.
    function markAppRead(app: string): void {
        const want = norm(app);
        if (want === "" || !root.history.some(e => !e.seen && norm(e.app) === want))
            return;
        root.history = root.history.map(e => !e.seen && norm(e.app) === want ? Object.assign({}, e, { seen: true }) : e);
    }
    function norm(s: string): string {
        return String(s ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");
    }

    // OPEN: the notification's default action if the app still offers one,
    // otherwise the app's window; then it leaves the list.
    function open(entry: var): void {
        const n = root._objects[entry.key];
        const action = n ? ((n.actions ?? []).find(a => a.identifier === "default") ?? (n.actions ?? [])[0] ?? null) : null;
        Deck.leave();
        if (action)
            action.invoke();
        else
            focusApp(entry.app);
        root.remove(entry.key);
    }
    function focusApp(app: string): void {
        const a = norm(app);
        if (a === "")
            return;
        Hyprland.dispatch(`(function() for _, w in ipairs(hl.get_windows()) do local c = string.lower(w.class or ""):gsub("[^a-z0-9]", "") if c == "${a}" or c:find("${a}", 1, true) then return hl.dsp.focus({ window = w }) end end return hl.dsp.no_op() end)()`);
    }
    Connections {
        target: Hyprland
        function onActiveToplevelChanged(): void {
            const cls = Hyprland.activeToplevel?.lastIpcObject?.class ?? "";
            if (cls !== "")
                root.markAppRead(cls);
        }
    }

    function forget(app: string): void {
        root.history = root.history.filter(e => e.app !== app);
    }

    // The history grouped by app, the app with the newest entry first.
    readonly property var groups: {
        const byApp = {};
        const order = [];
        for (const e of history) {
            if (!byApp[e.app]) {
                byApp[e.app] = [];
                order.push(e.app);
            }
            byApp[e.app].push(e);
        }
        return order.map(app => ({ app: app, entries: byApp[app] }));
    }

    // **While any window is fullscreen, notifications are silent**: they go
    // straight to the history, and when fullscreen ends one card says how many
    // were held and from where. Critical ones still show at once. Read from
    // Hyprland's own workspace state, refreshed on its `fullscreen` event.
    readonly property bool fullscreen: {
        const active = (Hyprland.monitors?.values ?? []).map(m => m.activeWorkspace?.id);
        return (Hyprland.workspaces?.values ?? []).some(ws => ws && active.indexOf(ws.id) >= 0 && (ws.lastIpcObject?.hasfullscreen ?? false));
    }
    property var _heldWhileFullscreen: []
    onFullscreenChanged: {
        if (fullscreen || _heldWhileFullscreen.length === 0)
            return;
        // "3 notifications held while you played" / "2 from Discord, 1 from
        // Steam. They're in COMMS."
        const apps = [];
        const counts = {};
        for (const a of _heldWhileFullscreen) {
            if (!(a in counts)) {
                apps.push(a);
                counts[a] = 0;
            }
            counts[a]++;
        }
        const n = _heldWhileFullscreen.length;
        _heldWhileFullscreen = [];
        const parts = apps.slice(0, 4).map(a => `${counts[a]} from ${a}`);
        const rest = apps.slice(4).reduce((t, a) => t + counts[a], 0);
        if (rest > 0)
            parts.push(`${rest} from others`);
        root.sendSummary(n === 1 ? "1 notification held while you played" : `${n} notifications held while you played`,
            `${parts.join(", ")}. They're in COMMS.`);
    }
    Connections {
        target: Hyprland
        function onRawEvent(event: HyprlandEvent): void {
            if (event.name === "fullscreen" || event.name === "workspace" || event.name === "focusedmon")
                Hyprland.refreshWorkspaces();
        }
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
            // The shell's own summary of what was held is not itself history.
            const internal = (notification.hints?.["x-wrayth-internal"] ?? "") !== "";
            const critical = root.levelOf(notification) === "CRITICAL";
            const hold = !critical && !internal && (root.dnd || (root.fullscreen && SystemSettings.notify === "hold")) && !Demo.active;
            if (!internal)
                root._remember(notification, hold);
            if (hold) {
                if (root.fullscreen && !root.dnd)
                    root._heldWhileFullscreen = root._heldWhileFullscreen.concat([(notification.appName || "UNKNOWN").trim()]);
                // Silent: straight to the history, no card.
                notification.expire();
                return;
            }
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

    // One of the shell's own that is not kept in the history (the fullscreen
    // summary: what it summarises already is).
    function sendSummary(summary: string, body: string): void {
        notifier.exec(["notify-send", "-a", "wrayth", "-u", "normal", "-h", "string:x-wrayth-internal:1", summary, body]);
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
