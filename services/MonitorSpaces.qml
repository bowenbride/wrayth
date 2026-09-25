import QtQuick
import Quickshell.Hyprland

// One monitor's view of the workspaces, for that monitor's bar: its active
// workspace, the five slots around it, and the page marker. See `Spaces` for
// why this is per monitor. The monitor is the bar's own, from `monitorFor` on
// the bar's screen; until Hyprland has reported it, the focused one stands in.
QtObject {
    id: root

    property var monitor: null
    readonly property var effectiveMonitor: monitor ?? Hyprland.focusedMonitor

    readonly property var monitorIpc: effectiveMonitor?.lastIpcObject ?? null
    readonly property int activeId: effectiveMonitor?.activeWorkspace?.id ?? monitorIpc?.activeWorkspace?.id ?? 1
    // "special:deck" while one is up on this monitor, "" otherwise.
    readonly property string activeSpecial: monitorIpc?.specialWorkspace?.name ?? ""
    readonly property bool special: activeSpecial.startsWith("special:")

    // The five slots. A numbered page is always five; a special page is padded
    // with empty slots, because the indicator's width is fixed and a short page
    // must not shrink it.
    readonly property var slots: {
        const out = [];
        if (special) {
            const current = activeSpecial.slice(8);
            const index = Math.max(0, Spaces.specials.indexOf(current));
            const page = Math.floor(index / Spaces.perPage);
            for (let i = 0; i < Spaces.perPage; i++) {
                const name = Spaces.specials[page * Spaces.perPage + i];
                out.push({
                    label: name === undefined ? "" : Spaces.labelFor(name),
                    target: name ?? "",
                    special: true,
                    empty: name === undefined,
                    active: name === current
                });
            }
            return out;
        }
        const page = Math.floor(Math.max(0, activeId - 1) / Spaces.perPage);
        for (let i = 0; i < Spaces.perPage; i++) {
            const id = page * Spaces.perPage + i + 1;
            out.push({
                label: `${id}`.padStart(2, "0"),
                target: `${id}`,
                special: false,
                empty: false,
                active: id === activeId
            });
        }
        return out;
    }

    // --- Pages, for the bar's page marker -----------------------------------
    // A page is in use if any of its workspaces exist or it is the active one.
    // Pages need not be contiguous -- workspaces 1 and 12 put pages 0 and 2 in
    // use and page 1 not -- so the pips follow the *used* pages in order, and
    // the lit one is the current page's place in that list rather than its
    // page number.
    readonly property var usedPages: {
        const pages = {};
        for (const ws of Hyprland.workspaces.values)
            if (ws.id >= 1)
                pages[Math.floor((ws.id - 1) / Spaces.perPage)] = true;
        pages[Math.floor(Math.max(0, activeId - 1) / Spaces.perPage)] = true;
        return Object.keys(pages).map(Number).sort((a, b) => a - b);
    }

    readonly property int currentPage: Math.floor(Math.max(0, activeId - 1) / Spaces.perPage)

    // `SPC` while a special workspace is up, otherwise the page number.
    readonly property string pageLabel: special ? "SPC" : `P${currentPage + 1}`

    // One pip per used page, plus a final one for the special page.
    //
    // The marker rests at three pips -- two numbered pages and the special
    // one -- rather than following the used pages down to a single pip. A lone
    // pip reads as a decoration beside the slots; a standing row of three reads
    // as the pager it is, and the pips stop appearing and vanishing as
    // workspaces come and go. Extra pips light up as pages beyond the second
    // come into use.
    readonly property int minNumberedPips: 2
    readonly property int numberedPips: Math.max(minNumberedPips, usedPages.length)
    readonly property int pipCount: numberedPips + 1
    readonly property int litPip: special ? numberedPips : Math.max(0, usedPages.indexOf(currentPage))

    // Which slot the bar's accent line runs to, or -1 when none is lit.
    readonly property int activeIndex: slots.findIndex(slot => slot.active)
}
