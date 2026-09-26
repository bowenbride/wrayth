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
        // **This screen's popup is the one showing the dropdown.** Only it
        // draws the panel and only it takes a focus grab; see
        // `ShellState.dropdownScreen` for why two grabs closed it at once.
        readonly property bool mine: ShellState.dropdownScreen === modelData?.name
        readonly property string wanted: mine ? ShellState.dropdown : ""
        // A focus grab cleared in the first `spuriousMs` after opening is
        // taken to be spurious -- nothing a person does lands that fast -- and
        // is taken again, once per opening, with the dropdown left open. A
        // second clear closes it as usual. `grabHeld` is what re-takes it: the
        // grab is active while armed *and* held, so dropping and restoring it
        // for a turn asks the compositor for a fresh one.
        readonly property int spuriousMs: 250
        property bool regrabbed: false
        property bool grabHeld: true
        // How far above its resting place the panel starts, i.e. how much of it
        // is still behind the bar at the start of the slide.
        readonly property real slide: 16

        screen: modelData
        color: "transparent"
        visible: current !== ""

        // Each dropdown may give its own width (AUDIO 400, TRAY 360, COMMS 420).
        implicitWidth: content.item?.panelWidth ?? Tokens.measure.dropdownStandard
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
            const avail = ShellState.barOn(popup.modelData?.name ?? "")?.width ?? popup.screen.width;
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
            duration: Tokens.motion.feedback
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.motion.easeIn
        }

        SequentialAnimation {
            id: swapAnim

            property string next: ""
            property real nextX: 0

            NumberAnimation {
                target: popup
                property: "reveal"
                to: 0
                duration: Math.round(Tokens.motion.feedback * 0.55)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeOut
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
                duration: Tokens.motion.feedback
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeIn
            }
        }

        onWantedChanged: popup.sync()

        function sync(): void {
            const want = popup.wanted;
            if (want !== "" && want !== popup.current)
                popup.regrabbed = false;

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

        Connections {
            target: ShellState

            function onBarHoveredChanged(): void {
                if (!ShellState.barHovered && popup.wanted !== "")
                    popup.grabArmed = true;
            }
        }

        function grabCleared(): void {
            if (popup.wanted === "")
                return;
            const age = Date.now() - ShellState.dropdownOpenedAt;
            if (age < popup.spuriousMs && !popup.regrabbed) {
                popup.regrabbed = true;
                ShellState.logDropdown(`${popup.wanted} on ${popup.modelData?.name}: focus grab cleared ${age} ms after opening; taken again, dropdown kept open`);
                popup.grabHeld = false;
                Qt.callLater(() => popup.grabHeld = true);
                return;
            }
            ShellState.closeDropdown(popup.regrabbed ? `focus grab cleared again, ${age} ms after opening (it had been taken again once)` : "focus grab cleared (a click outside, or the compositor ended the grab)");
        }

        // A click anywhere outside closes. Every bar is in the list, so a click
        // on any readout -- on any screen -- reaches it and switches dropdowns
        // in one go instead of counting as a click outside.
        HyprlandFocusGrab {
            active: popup.grabArmed && popup.grabHeld && popup.wanted !== ""
            windows: [popup].concat(ShellState.barWindows.filter(b => b))
            onCleared: popup.grabCleared()
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
                    ShellState.closeDropdown("Escape");
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
                onClicked: ShellState.closeDropdown("click on the empty space under the panel")
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
                    case "audio":
                        return audioPanel;
                    case "tray":
                        return trayPanel;
                    case "comms":
                        return commsPanel;
                    case "calendar":
                        return calendarPanel;
                    case "input":
                        return inputPanel;
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
                id: audioPanel

                AudioDropdown {
                    width: holder.width
                }
            }

            Component {
                id: trayPanel

                TrayDropdown {
                    width: holder.width
                }
            }

            Component {
                id: commsPanel

                CommsDropdown {
                    width: holder.width
                }
            }

            Component {
                id: inputPanel

                InputDropdown {
                    width: holder.width
                }
            }

            Component {
                id: calendarPanel

                CalendarDropdown {
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
