import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// The wallpaper layer, one surface per screen, below everything else.
Variants {
    model: ShellState.screens

    PanelWindow {
        required property ShellScreen modelData

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

            // Crisp on an empty workspace, the lockscreen's treatment once
            // something is open. Wallpaper animates both over 250 ms.
            blurRadius: Desktop.occupied ? 16 : 0
            dim: Desktop.occupied ? 0.58 : 0
        }

        // Only under EVERYTHING. This surface is behind every window, so lines
        // on it never touch window content whatever the exclusion says.
        Scanlines {
            surface: "wallpaper"
        }
    }
}
