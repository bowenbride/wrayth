pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Battery state from UPower, power profiles from power-profiles-daemon.
// Quickshell exposes PowerProfiles.profile read-only, so setting one goes
// through powerprofilesctl; the D-Bus property then updates on its own.
Singleton {
    id: root

    readonly property var battery: UPower.displayDevice
    readonly property bool onBattery: UPower.onBattery
    readonly property real charge: (battery?.percentage ?? 0) * 100
    readonly property bool present: battery?.isPresent ?? false

    readonly property int profile: PowerProfiles.profile
    readonly property bool hasPerformance: PowerProfiles.hasPerformanceProfile

    // Tile order in the dropdown, with the names powerprofilesctl expects.
    readonly property var profiles: [
        {
            id: PowerProfile.PowerSaver,
            cli: "power-saver",
            label: "SAVER",
            katakana: "省電力"
        },
        {
            id: PowerProfile.Balanced,
            cli: "balanced",
            label: "BALANCED",
            katakana: "均衡"
        },
        {
            id: PowerProfile.Performance,
            cli: "performance",
            label: "PERFORMANCE",
            katakana: "全開"
        }
    ]

    function setProfile(cli: string): void {
        setProc.command = ["powerprofilesctl", "set", cli];
        setProc.running = true;
    }

    // The charge state, as the dropdown header words it.
    function stateLabel(): string {
        switch (battery?.state ?? UPowerDeviceState.Unknown) {
        case UPowerDeviceState.Charging:
            return "CHARGING";
        case UPowerDeviceState.Discharging:
            return "DISCHARGING";
        case UPowerDeviceState.Empty:
            return "EMPTY";
        case UPowerDeviceState.FullyCharged:
            return "CHARGED";
        case UPowerDeviceState.PendingCharge:
            return "PENDING CHARGE";
        case UPowerDeviceState.PendingDischarge:
            return "PENDING DISCHARGE";
        default:
            return "UNKNOWN";
        }
    }

    Process {
        id: setProc
    }
}
