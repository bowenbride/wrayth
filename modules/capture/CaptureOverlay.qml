import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// The screenshot selector (Print), on the focused screen only. The screen
// dims; the selection is a square-cornered frame in the accent -- square,
// because it must show exactly what will be captured -- with its size in
// pixels beside it, and the modes as chips: REGION (drag), WINDOW (the window
// under the pointer), SCREEN (all of it). Tab switches, Enter captures,
// Escape cancels.
//
// None of this is in the image: the surface is hidden, and its layer has no
// fade, before the capture runs (Screenshot.captureFromSelector).
Variants {
    model: ShellState.screens

    PanelWindow {
        id: overlay

        required property ShellScreen modelData
        readonly property bool shown: ShellState.captureOpen && ShellState.overlayScreen === modelData?.name

        // This monitor in Hyprland's layout coordinates: where the selection
        // is translated to for grim, and the scale its pixels are counted in.
        // Hyprland's own figures, asked for afresh when the selector opens
        // (see Screenshot.monitorBox).
        readonly property var monitorIpc: Hyprland.monitorFor(modelData)?.lastIpcObject ?? null
        readonly property real originX: monitorIpc?.x ?? 0
        readonly property real originY: monitorIpc?.y ?? 0
        readonly property real scale: monitorIpc?.scale ?? 1

        // The selection, in this surface's coordinates. `valid` once it has
        // an area.
        property real selX: 0
        property real selY: 0
        property real selW: 0
        property real selH: 0
        readonly property bool valid: selW >= 2 && selH >= 2

        readonly property string mode: Screenshot.mode

        screen: modelData
        color: "transparent"
        visible: shown

        WlrLayershell.layer: WlrLayer.Overlay
        // Its own namespace, with no fade: gone the moment it is hidden.
        WlrLayershell.namespace: "wrayth-capture"
        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        onShownChanged: {
            if (!shown)
                return;
            selX = selY = selW = selH = 0;
            Hyprland.refreshToplevels();
            Hyprland.refreshMonitors();
            keys.take();
        }
        onModeChanged: {
            if (mode === "screen") {
                selX = 0;
                selY = 0;
                selW = width;
                selH = height;
            } else {
                selX = selY = selW = selH = 0;
                if (mode === "window")
                    pickWindow(pointer.lastX, pointer.lastY);
            }
        }

        // The windows showing on this monitor, most recently focused first
        // (the order they stack in), in this surface's coordinates.
        function windows(): var {
            const m = monitorIpc;
            if (!m)
                return [];
            const ws = [m.activeWorkspace?.id, m.specialWorkspace?.id].filter(id => id !== undefined && id !== 0);
            return (Hyprland.toplevels?.values ?? []).map(t => t?.lastIpcObject).filter(o => o && o.mapped !== false && !o.hidden
                && o.monitor === m.id && ws.indexOf(o.workspace?.id) >= 0 && o.at && o.size)
                .sort((a, b) => (a.focusHistoryID ?? 99) - (b.focusHistoryID ?? 99))
                .map(o => ({ x: o.at[0] - originX, y: o.at[1] - originY, w: o.size[0], h: o.size[1] }));
        }
        function pickWindow(px: real, py: real): void {
            const w = windows().find(r => px >= r.x && px < r.x + r.w && py >= r.y && py < r.y + r.h);
            if (w) {
                selX = w.x;
                selY = w.y;
                selW = w.w;
                selH = w.h;
            } else {
                selX = selY = selW = selH = 0;
            }
        }

        function cycleMode(step: int): void {
            const at = Screenshot.modes.indexOf(mode);
            Screenshot.mode = Screenshot.modes[(at + step + Screenshot.modes.length) % Screenshot.modes.length];
        }

        function capture(): void {
            if (!valid)
                return;
            const x = Math.round(originX + selX), y = Math.round(originY + selY);
            Screenshot.captureFromSelector(`${x},${y} ${Math.round(selW)}x${Math.round(selH)}`, overlay.scale);
        }

        // --- The dim, everywhere but the selection -------------------------
        readonly property color dim: Qt.rgba(0, 0, 0, 0.5)
        Rectangle { x: 0; y: 0; width: parent.width; height: overlay.valid ? overlay.selY : parent.height; color: overlay.dim }
        Rectangle { visible: overlay.valid; x: 0; y: overlay.selY; width: overlay.selX; height: overlay.selH; color: overlay.dim }
        Rectangle { visible: overlay.valid; x: overlay.selX + overlay.selW; y: overlay.selY; width: parent.width - x; height: overlay.selH; color: overlay.dim }
        Rectangle { visible: overlay.valid; x: 0; y: overlay.selY + overlay.selH; width: parent.width; height: parent.height - y; color: overlay.dim }

        // The frame: square, 1 px, just outside the selection, so everything
        // inside it -- and nothing else -- is what is captured.
        Rectangle {
            visible: overlay.valid
            x: overlay.selX - 1
            y: overlay.selY - 1
            width: overlay.selW + 2
            height: overlay.selH + 2
            color: "transparent"
            border.width: 1
            border.color: Tokens.color.accent
        }

        // The size, in the pixels the image will have.
        Rectangle {
            id: sizeTag

            visible: overlay.valid
            readonly property bool below: overlay.selY + overlay.selH + height + 8 < overlay.height
            x: Math.max(0, Math.min(overlay.width - width, overlay.selX - 1))
            y: below ? overlay.selY + overlay.selH + 6 : Math.max(0, overlay.selY - height - 6)
            width: sizeLabel.implicitWidth + 12
            height: sizeLabel.implicitHeight + 6
            color: Tokens.color.accent

            NrLabel {
                id: sizeLabel

                anchors.centerIn: parent
                centred: true
                color: Tokens.color.ground
                text: `${Math.round(overlay.selW * overlay.scale)} × ${Math.round(overlay.selH * overlay.scale)}`
            }
        }

        // --- The pointer: drawing a region, or picking a window ------------
        MouseArea {
            id: pointer

            property real lastX: width / 2
            property real lastY: height / 2
            property real startX: 0
            property real startY: 0

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: overlay.mode === "region" ? Qt.CrossCursor : Qt.PointingHandCursor

            onPositionChanged: mouse => {
                lastX = mouse.x;
                lastY = mouse.y;
                if (overlay.mode === "window")
                    overlay.pickWindow(mouse.x, mouse.y);
                else if (overlay.mode === "region" && pressed) {
                    overlay.selX = Math.min(startX, mouse.x);
                    overlay.selY = Math.min(startY, mouse.y);
                    overlay.selW = Math.abs(mouse.x - startX);
                    overlay.selH = Math.abs(mouse.y - startY);
                }
            }
            onPressed: mouse => {
                if (overlay.mode === "region") {
                    startX = mouse.x;
                    startY = mouse.y;
                    overlay.selX = mouse.x;
                    overlay.selY = mouse.y;
                    overlay.selW = 0;
                    overlay.selH = 0;
                }
            }
            // A window or the screen is chosen by clicking it too.
            onClicked: mouse => {
                if (overlay.mode !== "region")
                    overlay.capture();
            }
        }

        // --- The modes and the keys, top centre ----------------------------
        ChamferPanel {
            anchors.horizontalCenter: parent.horizontalCenter
            y: 48
            width: bar.implicitWidth + 28
            height: 44
            chamfer: Appearance.chamfer.panel
            fillColor: Tokens.color.panel2

            // Swallows clicks, so they never draw a region under the chips.
            MouseArea {
                anchors.fill: parent
            }

            Row {
                id: bar

                anchors.centerIn: parent
                spacing: 8

                NrLabel {
                    id: captureTitle

                    anchors.verticalCenter: parent.verticalCenter
                    color: Tokens.color.bright
                    text: "CAPTURE"
                }
                KanaTag {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "撮影"
                    title: captureTitle
                }

                Item {
                    width: 6
                    height: 1
                }

                Repeater {
                    model: Screenshot.modes

                    Rectangle {
                        id: chip

                        required property string modelData
                        readonly property bool selected: overlay.mode === modelData

                        anchors.verticalCenter: parent.verticalCenter
                        width: chipLabel.implicitWidth + 16
                        height: 22
                        color: selected ? Theme.alpha(Tokens.color.accent, 0.14) : "transparent"
                        border.width: Tokens.measure.hairline
                        border.color: selected ? Tokens.color.accent : Tokens.color.hair

                        Behavior on color {
                            ColorAnimation {
                                duration: Tokens.motion.feedback
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Tokens.motion.easeIn
                            }
                        }

                        NrLabel {
                            id: chipLabel

                            anchors.centerIn: parent
                            centred: true
                            color: chip.selected ? Tokens.color.accent : Tokens.color.text
                            text: chip.modelData.toUpperCase()
                        }
                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: Screenshot.mode = chip.modelData
                        }
                    }
                }

                Item {
                    width: 6
                    height: 1
                }

                Keycap {
                    anchors.verticalCenter: parent.verticalCenter
                    key: "TAB"
                    color: Tokens.color.mute
                }
                NrLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tokens.color.mute
                    text: "MODE"
                }
                Keycap {
                    anchors.verticalCenter: parent.verticalCenter
                    key: "ENTER"
                    color: Tokens.color.mute
                }
                NrLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tokens.color.mute
                    text: "CAPTURE"
                }
                Keycap {
                    anchors.verticalCenter: parent.verticalCenter
                    key: "ESC"
                    color: Tokens.color.mute
                }
                NrLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tokens.color.mute
                    text: "CANCEL"
                }
            }
        }

        OverlayKeys {
            id: keys

            anchors.fill: parent
            active: overlay.shown
            onEscaped: {
                Screenshot.forRecording = false;
                ShellState.captureOpen = false;
            }
            Keys.onReturnPressed: overlay.capture()
            Keys.onEnterPressed: overlay.capture()
            Keys.onTabPressed: event => {
                overlay.cycleMode(1);
                event.accepted = true;
            }
            Keys.onBacktabPressed: event => {
                overlay.cycleMode(-1);
                event.accepted = true;
            }
        }
    }
}
