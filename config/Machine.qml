pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Host facts the shell labels itself with, all **detected**, not hard-coded, so
// the shell is portable to any machine. Kept in one place so the bar, HUD and
// lockscreen all say the same thing.
Singleton {
    id: root

    property string hostname: "localhost"

    // The interface carrying the default route -- the one actually in use -- for
    // the net rate readout and the "NET // <iface>" label. Falls back to the
    // first wireless device, then the first non-loopback device, then "" (a
    // desktop with the cable unplugged and no wifi). Empty is handled: the net
    // readout reads zero and the sparkline stays flat rather than erroring.
    property string netInterface: ""
    // The wireless device, for the Wi-Fi dropdown's nmcli calls specifically --
    // which must talk to the wifi radio even when a cable is the active route.
    // Falls back to the active interface, then "".
    property string wifiInterface: ""

    // CPU marketing name and thread count for the HUD, from /proc.
    property string cpuModel: ""
    property int threadCount: 1

    // KRN in the HUD footer. Read once: it cannot change without a reboot.
    property string kernel: ""

    Process {
        running: true
        command: ["uname", "-r"]
        stdout: StdioCollector {
            onStreamFinished: root.kernel = text.trim()
        }
    }

    // One shell call for the network interfaces, so the two answers are read
    // from the same moment.
    Process {
        running: true
        command: ["sh", "-c", "act=$(ip route show default 2>/dev/null | grep -oP 'dev \\K\\S+' | head -1); wl=''; for w in /sys/class/net/*/wireless; do [ -e \"$w\" ] && wl=$(basename \"$(dirname \"$w\")\") && break; done; [ -z \"$act\" ] && act=$wl; [ -z \"$act\" ] && act=$(ls /sys/class/net 2>/dev/null | grep -vx lo | head -1); [ -z \"$wl\" ] && wl=$act; printf '%s\\n%s\\n' \"$act\" \"$wl\""]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n");
                root.netInterface = (lines[0] ?? "").trim();
                root.wifiInterface = (lines[1] ?? "").trim() || root.netInterface;
            }
        }
    }

    // A short CPU name: /proc/cpuinfo's model name with the marketing noise
    // (trademark marks, "CPU @ ...", the generation prefix, the vendor word)
    // trimmed off, so the HUD reads "Core i5-12400" or "Ryzen 7 5800X" rather
    // than the full string. Thread count is nproc.
    Process {
        running: true
        command: ["sh", "-c", "awk -F: '/model name/{m=$2; exit} END{gsub(/\\(R\\)|\\(TM\\)|\\(r\\)|\\(tm\\)/,\"\",m); sub(/ @.*/,\"\",m); sub(/ CPU$/,\"\",m); sub(/^ *[0-9]+th Gen /,\"\",m); sub(/^ *Intel */,\"\",m); sub(/^ *AMD */,\"\",m); gsub(/^ +| +$/,\"\",m); gsub(/  +/,\" \",m); print m}' /proc/cpuinfo; nproc"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.trim().split("\n");
                root.cpuModel = (lines[0] ?? "").trim() || "CPU";
                root.threadCount = Math.max(1, parseInt(lines[lines.length - 1]) || 1);
            }
        }
    }

    FileView {
        path: "/etc/hostname"
        printErrors: false
        onLoaded: {
            const name = text().trim();
            if (name)
                root.hostname = name;
        }
    }
}
