pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray

// The tray's apps, in a stable order (by name), for the bar's count and the
// TRAY dropdown. Quickshell is the StatusNotifierWatcher; items arrive and
// leave as the apps register, so nothing here polls.
Singleton {
    id: root

    readonly property var items: (SystemTray.items?.values ?? []).filter(i => i).slice().sort((a, b) => root.nameOf(a).localeCompare(root.nameOf(b)))

    // A short status line, when the app gives one: its tooltip's text if that
    // is short, else NEEDS ATTENTION when it asks for it. "" otherwise.
    function statusOf(item: var): string {
        const d = (item?.tooltipDescription ?? "").replace(/<[^>]*>/g, "").trim();
        if (d !== "" && d.length <= 24 && d.indexOf("\n") < 0)
            return d.toUpperCase();
        return item?.status === Status.NeedsAttention ? "NEEDS ATTENTION" : "";
    }

    // The app's own name, as plainly as it gives one.
    function nameOf(item: var): string {
        const name = (item?.title || item?.tooltipTitle || item?.id || "").trim();
        return name || "UNNAMED";
    }
}
