import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Bottom-centre, 96px above the screen edge. Shares the popup namespace, whose
// layer animation is off, so the fade and drop below are the whole motion.
Variants {
    model: ShellState.screens

    PanelWindow {
        id: osd

        required property ShellScreen modelData

        // On the focused screen only, not every one.
        readonly property bool shown: Osd.showing !== "" && ShellState.focusedScreen === modelData.name

        screen: modelData
        color: "transparent"
        // Faded by the compositor, see the layer rule in hypr-wrayth.lua.
        visible: shown

        implicitWidth: 400
        implicitHeight: 74

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wrayth-popup"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        exclusionMode: ExclusionMode.Ignore

        anchors {
            bottom: true
        }

        margins.bottom: 96

        // Nothing here takes the pointer.
        mask: Region {}


        OsdPanel {
            anchors.fill: parent

            // Falls back to what was last shown, so the panel does not change
            // identity on its way off screen.
            volume: (Osd.showing || Osd.lastShown) === "volume"
        }
    }
}
