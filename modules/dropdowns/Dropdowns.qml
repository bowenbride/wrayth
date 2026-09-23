import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.config
import qs.services

// The layer the bar dropdowns live on. The surface is sized to the panel and
// nothing more: the `wrayth-popup` layer rule blurs whatever it covers
// (Caelestia's decoration sets ignore_opacity, so alpha does not limit it), so a
// full-screen surface would frost the whole screen. It anchors top-left with a
// zero exclusive zone, which puts its origin on the bar's, and slides down from
// under the bar in QML — Hyprland's own layer animation is off for this
// namespace, see external/hypr-wrayth.lua.
Variants {
    model: ShellState.screens

    PanelWindow {
        id: popup

        required property ShellScreen modelData

        // Keep-off-the-edge margin, and the gap below the bar.
        readonly property real edge: 12
        readonly property real gap: 8

        // Which panel the loader holds, and where the surface sits. Both lag
        // ShellState: `current` so the panel stays drawn while it slides back
        // up, `anchorX` so the surface never moves under a panel that is still
        // on screen — binding it straight to ShellState.dropdownAnchorX made a
        // swap teleport the outgoing panel to the incoming readout first.
        property string current: ""
        property real anchorX: 0
        // The surface is sized to the panel, but a panel that animates its own
        // height between two inner views exposes a stable `surfaceHeight` (the
        // taller of the two) so the *surface* never reconfigures mid-animation
        // -- only the visible panel inside it grows and shrinks. Reconfiguring
        // the layer every frame is exactly what made the height animation
        // stutter; see implicitHeight below.
        readonly property real panelHeight: content.item?.surfaceHeight ?? content.item?.implicitHeight ?? 0

        // 0 hidden, 1 fully out. This only slides the panel *inside* the
        // surface; the surface's own fade is the compositor's, from the
        // `animation = fade` layer rule.
        property real reveal: 0

        // Hyprland refocuses the pointer the moment a focus grab starts. When
        // that lands with the pointer still on the bar, the bar loses its hover
        // state until the mouse moves, so the readout just clicked stops looking
        // clickable. The grab is only there to catch clicks outside the bar and
        // making one of those means moving off the bar first, so it holds until
        // the pointer leaves and then stays armed until the dropdown closes.
        property bool grabArmed: false
        // How far above its resting place the panel starts, i.e. how much of it
        // is still behind the bar at the start of the slide.
        readonly property real slide: 16

        screen: modelData
        color: "transparent"
        visible: current !== ""

        implicitWidth: 380
        // Fixed to the panel. Animating this instead would reconfigure the layer
        // surface on every frame, which Hyprland cannot keep up with — that is
        // what made the slide stutter.
        implicitHeight: Math.max(1, Math.round(panelHeight))

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wrayth-popup"
        // OnDemand plus the focus grab below: the grab hands the surface the
        // keyboard while it is up, so Escape and the passphrase field get keys
        // without the surface stealing them from everything else.
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

        exclusionMode: ExclusionMode.Normal
        exclusiveZone: 0

        anchors {
            top: true
            left: true
        }

        margins.top: gap
        // Under the readout that opened it, pulled back in if that would hang
        // the panel off the right edge. Both windows share an origin, so the
        // bar's x maps straight across.
        margins.left: {
            const avail = ShellState.barWindow?.width ?? popup.screen.width;
            return Math.round(Math.max(popup.edge, Math.min(popup.anchorX, avail - popup.implicitWidth - popup.edge)));
        }

        // Open, close and swap are three explicit animations rather than one
        // Behavior on `reveal`. A swap has to take the old panel out, change the
        // panel underneath, and bring the new one back in; a Behavior only ever
        // sees the end value, which is why switching dropdowns used to flash.
        NumberAnimation {
            id: openAnim

            target: popup
            property: "reveal"
            to: 1
            duration: Appearance.duration.state
            easing.type: Easing.OutCubic
        }

        SequentialAnimation {
            id: swapAnim

            property string next: ""
            property real nextX: 0

            NumberAnimation {
                target: popup
                property: "reveal"
                to: 0
                duration: Math.round(Appearance.duration.state * 0.55)
                easing.type: Easing.InCubic
            }
            // The surface moves and resizes to the incoming panel here, with
            // nothing drawn in it.
            ScriptAction {
                script: {
                    popup.anchorX = swapAnim.nextX;
                    popup.current = swapAnim.next;
                }
            }
            NumberAnimation {
                target: popup
                property: "reveal"
                to: 1
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }

        Connections {
            target: ShellState

            function onDropdownChanged(): void {
                const want = ShellState.dropdown;

                // **The ID editor arms at once.** It is typed into the moment
                // it opens, from a click on the bar -- and with the pointer
                // still over the bar, an unarmed grab left the surface without
                // the keyboard (measured: the editor's window went active and
                // lost it again 4 ms later, and a key typed then never arrived)
                // until the pointer moved into the panel. The other panels are
                // reached by moving into them first, and keep the wait.
                popup.grabArmed = want !== "" && (!ShellState.barHovered || want === "ident");

                openAnim.stop();
                swapAnim.stop();

                if (want === "") {
                    // Immediate: the compositor fades the surface on unmap.
                    popup.reveal = 0;
                    popup.current = "";
                } else if (popup.current === "" || popup.current === want) {
                    // Nothing showing, or the same panel caught mid-close.
                    popup.anchorX = ShellState.dropdownAnchorX;
                    popup.current = want;
                    openAnim.start();
                } else {
                    swapAnim.next = want;
                    swapAnim.nextX = ShellState.dropdownAnchorX;
                    swapAnim.start();
                }
            }

            function onBarHoveredChanged(): void {
                if (!ShellState.barHovered && ShellState.dropdown !== "")
                    popup.grabArmed = true;
            }
        }

        // A click anywhere outside closes. The bar is in the list so clicking
        // another readout reaches it and switches dropdowns in one go.
        HyprlandFocusGrab {
            active: popup.grabArmed
            windows: ShellState.barWindow ? [popup, ShellState.barWindow] : [popup]
            onCleared: ShellState.dropdown = ""
        }

        Item {
            id: holder

            focus: true

            anchors.left: parent.left
            anchors.right: parent.right
            height: popup.panelHeight
            // Slides down into place from under the bar. Whatever is still above
            // the surface top is simply not drawn, so the bar hides it.
            y: -popup.slide * (1 - popup.reveal)

            // A dropdown that has an inner view open (the Wi-Fi settings view)
            // takes Escape to step back out of it first; otherwise Escape
            // closes the dropdown.
            Keys.onEscapePressed: {
                if (content.item && content.item.canGoBack === true)
                    content.item.goBack();
                else
                    ShellState.dropdown = "";
            }

            // Below a short view the surface is sized to the taller one, so
            // there is transparent space under the visible panel; a click there
            // closes the dropdown like any click off it. Zero-height, and so
            // inert, for a panel that fills the surface.
            MouseArea {
                anchors.top: content.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                onClicked: ShellState.dropdown = ""
            }

            Loader {
                id: content

                width: parent.width
                active: popup.current !== ""

                sourceComponent: {
                    switch (popup.current) {
                    case "ident":
                        return identPanel;
                    case "wifi":
                        return wifiPanel;
                    case "bluetooth":
                        return bluetoothPanel;
                    case "power":
                        return powerPanel;
                    default:
                        return null;
                    }
                }
            }

            Component {
                id: identPanel

                IdentDropdown {
                    width: holder.width
                }
            }

            Component {
                id: wifiPanel

                WifiDropdown {
                    width: holder.width
                }
            }

            Component {
                id: bluetoothPanel

                BluetoothDropdown {
                    width: holder.width
                }
            }

            Component {
                id: powerPanel

                PowerDropdown {
                    width: holder.width
                }
            }
        }
    }
}
