import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// A preview of the lockscreen, for checking how it looks without locking:
// the same LockSurface in an ordinary overlay window on the focused screen.
// **It cannot authenticate or unlock anything** -- the real password input
// lives in LockScreen, not in LockSurface -- and it takes no keyboard at all.
// Opened with `lock preview`, closed with `lock endPreview` or by itself after
// ten seconds.
Scope {
    id: root

    readonly property bool shown: ShellState.lockPreviewOpen && !ShellState.locked
    onShownChanged: if (shown) limit.restart()
    Timer {
        id: limit
        interval: 10000
        onTriggered: ShellState.lockPreviewOpen = false
    }

    LazyLoader {
        active: root.shown

        PanelWindow {
            screen: Quickshell.screens.find(s => s.name === ShellState.focusedScreen) ?? Quickshell.screens[0]
            color: "black"

            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "wrayth-lock-preview"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            exclusionMode: ExclusionMode.Ignore

            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            LockSurface {
                anchors.fill: parent
                fade: 1
            }
            // Any click ends the preview.
            MouseArea {
                anchors.fill: parent
                onClicked: ShellState.lockPreviewOpen = false
            }
        }
    }
}
