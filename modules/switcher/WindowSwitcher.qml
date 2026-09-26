import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.components.ui as UI
import qs.config
import qs.services

// The window switcher (Alt + Tab): every window, most recently used first,
// across all workspaces. Hold Alt and tap Tab to move on, Shift + Tab to go
// back; letting go of Alt focuses the one selected. Escape cancels.
//
// Alt + Tab is a Hyprland bind (`switcher next`), so each tap reaches the
// shell through IPC even while this has the keyboard; the release of Alt is
// a plain key event here. Previews are one frame each, taken on open, and go
// with the surface when it closes.
Variants {
    model: ShellState.screens

    PanelWindow {
        id: overlay

        required property ShellScreen modelData
        readonly property bool shown: ShellState.switcherOpen && ShellState.overlayScreen === modelData?.name

        screen: modelData
        color: "transparent"
        visible: shown

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wrayth-overlay"
        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Loader {
            anchors.fill: parent
            active: overlay.shown
            sourceComponent: Item {
                id: view

                // Most recently used first: Hyprland's focus history.
                readonly property var windows: (Hyprland.toplevels?.values ?? []).filter(t => t?.lastIpcObject && (t.lastIpcObject.mapped ?? true) && (t.workspace?.id ?? 0) !== 0).slice().sort((a, b) => (a.lastIpcObject.focusHistoryID ?? 99) - (b.lastIpcObject.focusHistoryID ?? 99))
                readonly property int count: windows.length
                readonly property int selected: count > 0 ? ((Switcher.step % count) + count) % count : 0

                function commit(): void {
                    const t = windows[selected];
                    ShellState.switcherOpen = false;
                    Switcher.focusWindow(t);
                }
                Connections {
                    target: Switcher
                    function onCommitRequested(): void {
                        view.commit();
                    }
                }

                readonly property int tileW: 240
                readonly property int gap: 10
                readonly property int shown: Math.min(5, Math.max(1, count))

                ChamferPanel {
                    id: panel

                    anchors.centerIn: parent
                    width: view.shown * view.tileW + (view.shown - 1) * view.gap + 36
                    height: body.implicitHeight + 36
                    chamfer: Tokens.chamfer.centred
                    fillColor: Tokens.color.panel2

                    Column {
                        id: body

                        x: 18
                        y: 18
                        width: parent.width - 36
                        spacing: 12

                        // Header: Title + JapaneseLabel, the hint line on the right.
                        Item {
                            width: parent.width
                            height: Tokens.measure.toggleHeight
                            UI.Title {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                text: "WINDOWS"
                                japanese: "窓"
                            }
                            Text {
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: "TAB NEXT · SHIFT + TAB BACK · RELEASE ALT TO SWITCH"
                                color: Tokens.color.dim
                                font.family: Tokens.type.hint.family
                                font.pixelSize: Tokens.type.hint.size
                                font.letterSpacing: Tokens.type.hint.size * Tokens.type.hint.tracking
                                renderType: Text.NativeRendering
                            }
                        }

                        // More than five scroll with the selection.
                        ListView {
                            id: strip

                            width: parent.width
                            height: 128 + 46 + 4
                            orientation: ListView.Horizontal
                            spacing: view.gap
                            interactive: false
                            clip: true
                            model: view.windows
                            currentIndex: view.selected
                            highlightFollowsCurrentItem: false
                            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                            delegate: Item {
                                id: tile

                                required property var modelData
                                required property int index
                                readonly property bool sel: index === view.selected
                                readonly property string cls: modelData.lastIpcObject?.class ?? ""

                                width: view.tileW
                                height: strip.height

                                ChamferPanel {
                                    id: frame

                                    // The selected tile lifts 4 px.
                                    y: tile.sel ? 0 : 4
                                    width: parent.width
                                    height: parent.height - 4
                                    chamfer: 0
                                    chamferTopLeft: 0
                                    chamferTopRight: 0
                                    chamferBottomRight: 0
                                    // The leftmost tile echoes the panel's
                                    // bottom-left chamfer.
                                    chamferBottomLeft: tile.index === 0 ? 10 : 0
                                    scanlines: false
                                    fillColor: tile.sel ? Tokens.color.accentFaint : "transparent"
                                    borderColor: tile.sel ? Tokens.color.accent : Tokens.color.hair

                                    Behavior on y {
                                        NumberAnimation {
                                            duration: Tokens.motion.feedback
                                            easing.type: Easing.BezierSpline
                                            easing.bezierCurve: Tokens.motion.easeIn
                                        }
                                    }

                                    // The 128 px live preview, one frame a
                                    // second while open, with its WS tag.
                                    Rectangle {
                                        x: 1
                                        y: 1
                                        width: parent.width - 2
                                        height: 128
                                        color: Theme.alpha(Tokens.color.ground, 0.6)
                                        clip: true

                                        ScreencopyView {
                                            id: shot
                                            anchors.fill: parent
                                            captureSource: tile.modelData.wayland
                                            live: false
                                        }
                                        Timer {
                                            interval: shot.hasContent ? 1000 : 120
                                            running: true
                                            repeat: true
                                            onTriggered: shot.captureFrame()
                                        }
                                        Rectangle {
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 5
                                            width: wsTag.implicitWidth + 10
                                            height: 16
                                            color: Theme.alpha(Tokens.color.ground, 0.85)
                                            border.width: 1
                                            border.color: Tokens.color.hair
                                            Text {
                                                id: wsTag
                                                anchors.centerIn: parent
                                                text: (tile.modelData.workspace?.id ?? 0) > 0 ? `WS ${tile.modelData.workspace.id}` : (tile.modelData.workspace?.name ?? "").replace(/^special:/, "").toUpperCase()
                                                color: Tokens.color.text
                                                font.family: Tokens.font.data
                                                font.pixelSize: 9
                                                font.letterSpacing: 9 * 0.12
                                                renderType: Text.NativeRendering
                                            }
                                        }
                                    }

                                    // Badge, app name, title.
                                    AppBadge {
                                        x: 8
                                        y: 128 + 10
                                        size: 22
                                        pixelSize: 10
                                        name: tile.cls
                                        selected: tile.sel
                                    }
                                    Text {
                                        x: 38
                                        y: 128 + 7
                                        width: parent.width - 46
                                        elide: Text.ElideRight
                                        text: tile.cls.replace(/^.*\./, "") || "APP"
                                        textFormat: Text.PlainText
                                        color: tile.sel ? Tokens.color.bright : Tokens.color.text
                                        font.family: Tokens.font.data
                                        font.pixelSize: 11
                                        font.weight: Tokens.font.dataWeight
                                        renderType: Text.NativeRendering
                                    }
                                    Text {
                                        x: 38
                                        y: 128 + 23
                                        width: parent.width - 46
                                        elide: Text.ElideRight
                                        text: tile.modelData.title
                                        textFormat: Text.PlainText
                                        color: Tokens.color.dim
                                        font.family: Tokens.font.data
                                        font.pixelSize: 9
                                        renderType: Text.NativeRendering
                                    }
                                }

                                TapHandler {
                                    onTapped: {
                                        Switcher.step = tile.index;
                                        view.commit();
                                    }
                                }
                            }
                        }
                    }
                }

                // Alt let go: focus the selection. The modifier test covers a
                // release Qt reports as some other key.
                OverlayKeys {
                    anchors.fill: parent
                    active: overlay.shown
                    onEscaped: ShellState.switcherOpen = false
                    Keys.onReleased: event => {
                        if (event.key === Qt.Key_Alt || !(event.modifiers & Qt.AltModifier))
                            view.commit();
                    }
                    Keys.onTabPressed: Switcher.step++
                    Keys.onBacktabPressed: Switcher.step--
                    Keys.onRightPressed: Switcher.step++
                    Keys.onLeftPressed: Switcher.step--
                    Keys.onReturnPressed: view.commit()
                }
            }
        }
    }
}
