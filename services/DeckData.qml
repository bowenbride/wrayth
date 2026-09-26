pragma Singleton

import QtQuick
import Quickshell
import qs.services

// **The deck's copies of the live figures: current while the deck is up,
// still while it is down.** The HUD is drawn only on the deck, but bound
// straight to SysInfo it re-evaluated every figure every second with the deck
// closed. These follow SysInfo while `deckVisible` and hold their last value
// otherwise; opening the deck picks the current values up at once.
Singleton {
    id: root

    readonly property bool live: ShellState.deckVisible

    property real cpuPercent: 0
    property real memUsedGib: 0
    property real memTotalGib: 0
    property real memPercent: 0
    property var netRxHistory: []
    property var netTxHistory: []
    property real netRxRate: 0
    property real netTxRate: 0

    Binding { target: root; property: "cpuPercent"; when: root.live; value: SysInfo.cpuPercent; restoreMode: Binding.RestoreNone }
    Binding { target: root; property: "memUsedGib"; when: root.live; value: SysInfo.memUsedGib; restoreMode: Binding.RestoreNone }
    Binding { target: root; property: "memTotalGib"; when: root.live; value: SysInfo.memTotalGib; restoreMode: Binding.RestoreNone }
    Binding { target: root; property: "memPercent"; when: root.live; value: SysInfo.memPercent; restoreMode: Binding.RestoreNone }
    Binding { target: root; property: "netRxHistory"; when: root.live; value: SysInfo.netRxHistory; restoreMode: Binding.RestoreNone }
    Binding { target: root; property: "netTxHistory"; when: root.live; value: SysInfo.netTxHistory; restoreMode: Binding.RestoreNone }
    Binding { target: root; property: "netRxRate"; when: root.live; value: SysInfo.netRxRate; restoreMode: Binding.RestoreNone }
    Binding { target: root; property: "netTxRate"; when: root.live; value: SysInfo.netTxRate; restoreMode: Binding.RestoreNone }
}
