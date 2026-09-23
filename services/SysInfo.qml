pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// CPU, memory and network counters for the bar. The HUD (step 5) reuses the
// per-thread figures, which come free from the same /proc/stat read.
Singleton {
    id: root

    // 0..100 across all threads.
    property real cpuPercent: 0
    // One 0..100 entry per thread, in /proc/stat order.
    property var cpuThreads: []

    property real memTotalKib: 0
    property real memUsedKib: 0
    readonly property real memTotalGib: memTotalKib / 1048576
    readonly property real memUsedGib: memUsedKib / 1048576
    readonly property real memPercent: memTotalKib > 0 ? memUsedKib / memTotalKib * 100 : 0

    // Seconds since boot. Cheap enough to keep running: the HUD footer and the
    // power menu both show it.
    property real uptimeSeconds: 0

    // Bytes per second.
    property real netRxRate: 0
    property real netTxRate: 0

    // Recent rates, oldest first. The bar sparkline takes the last 12 points and
    // the HUD's takes 13, so keep a little more than either needs.
    readonly property int netHistoryLength: 16
    property var netRxHistory: []
    property var netTxHistory: []

    // --- CPU ----------------------------------------------------------------
    // Previous cumulative jiffies, keyed by cpu line index (0 = aggregate).
    property var _cpuPrev: []

    FileView {
        id: statFile

        path: "/proc/stat"
        printErrors: false
        onLoaded: root._readCpu(text())
    }

    function _readCpu(contents: string): void {
        if (!contents)
            return;

        const rows = [];
        for (const line of contents.split("\n")) {
            if (!line.startsWith("cpu"))
                break;
            const parts = line.split(/\s+/);
            const nums = parts.slice(1).map(Number);
            // user nice system idle iowait irq softirq steal ...
            const idle = (nums[3] || 0) + (nums[4] || 0);
            let total = 0;
            for (const n of nums)
                total += n || 0;
            rows.push({
                idle,
                total
            });
        }
        if (rows.length === 0)
            return;

        const prev = _cpuPrev;
        if (prev.length === rows.length) {
            const usage = rows.map((row, i) => {
                const dTotal = row.total - prev[i].total;
                const dIdle = row.idle - prev[i].idle;
                if (dTotal <= 0)
                    return 0;
                return Math.max(0, Math.min(100, (dTotal - dIdle) / dTotal * 100));
            });
            cpuPercent = usage[0];
            cpuThreads = usage.slice(1);
        }
        _cpuPrev = rows;
    }

    // --- Memory -------------------------------------------------------------
    FileView {
        id: memFile

        path: "/proc/meminfo"
        printErrors: false
        onLoaded: {
            const contents = text();
            const total = contents.match(/MemTotal:\s+(\d+)/);
            const available = contents.match(/MemAvailable:\s+(\d+)/);
            if (!total || !available)
                return;
            root.memTotalKib = Number(total[1]);
            root.memUsedKib = Number(total[1]) - Number(available[1]);
        }
    }

    // --- Uptime -------------------------------------------------------------
    FileView {
        id: uptimeFile

        path: "/proc/uptime"
        printErrors: false
        onLoaded: {
            const value = parseFloat(text().split(" ")[0]);
            if (isFinite(value))
                root.uptimeSeconds = value;
        }
    }

    // --- Network ------------------------------------------------------------
    property real _rxPrev: -1
    property real _txPrev: -1
    property real _netStamp: 0

    FileView {
        id: rxFile

        path: `/sys/class/net/${Machine.netInterface}/statistics/rx_bytes`
        printErrors: false
    }

    FileView {
        id: txFile

        path: `/sys/class/net/${Machine.netInterface}/statistics/tx_bytes`
        printErrors: false
    }

    function _readNet(): void {
        const rx = Number(rxFile.text());
        const tx = Number(txFile.text());
        if (!isFinite(rx) || !isFinite(tx) || rxFile.text() === "")
            return;

        const now = Date.now();
        const elapsed = (now - _netStamp) / 1000;
        if (_rxPrev >= 0 && elapsed > 0) {
            // Counters reset on interface down; clamp rather than show a spike.
            netRxRate = Math.max(0, (rx - _rxPrev) / elapsed);
            netTxRate = Math.max(0, (tx - _txPrev) / elapsed);

            netRxHistory = netRxHistory.concat(netRxRate).slice(-netHistoryLength);
            netTxHistory = netTxHistory.concat(netTxRate).slice(-netHistoryLength);
        }
        _rxPrev = rx;
        _txPrev = tx;
        _netStamp = now;
    }

    // --- Polling ------------------------------------------------------------
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            statFile.reload();
            uptimeFile.reload();
            rxFile.reload();
            txFile.reload();
            // The reloads are async; read the counters from the previous tick so
            // the rate always spans a known interval.
            root._readNet();
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: memFile.reload()
    }
}
