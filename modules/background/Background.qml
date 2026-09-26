import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// The wallpaper layer, one surface per screen, below everything else.
Variants {
    model: ShellState.screens

    PanelWindow {
        id: background

        required property ShellScreen modelData

        // This screen's own workspace, not the focused one: with two monitors,
        // opening a window on one used to blur the other's empty desktop too.
        readonly property bool occupied: Desktop.occupiedOn(modelData)

        screen: modelData
        color: Theme.deep

        WlrLayershell.layer: WlrLayer.Background
        WlrLayershell.namespace: "wrayth-background"
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Wallpaper {
            anchors.fill: parent
            // This screen's own wallpaper when the pool is PER SCREEN.
            source: Wallpapers.displayedFor(background.modelData?.name ?? "")
            // A video plays only on an empty workspace, with nothing
            // fullscreen, on AC; otherwise it holds its frame.
            allowVideo: true
            videoPlaying: !background.occupied && !SystemSettings.fullscreen && !Power.onBattery

            // Crisp on an empty workspace, the lockscreen's treatment once
            // something is open. Wallpaper animates both over 250 ms.
            blurRadius: background.occupied ? 16 : 0
            dim: background.occupied ? 0.58 : 0
        }

        // Only under EVERYTHING. This surface is behind every window, so lines
        // on it never touch window content whatever the exclusion says.
        Scanlines {
            surface: "wallpaper"
        }
    }
}
