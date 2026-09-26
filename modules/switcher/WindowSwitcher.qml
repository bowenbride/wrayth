import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
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
                    if (t)
                        Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${t.address}" })`);
                }
                Connections {
                    target: Switcher
                    function onCommitRequested(): void {
                        view.commit();
                    }
                }

                ChamferPanel {
                    anchors.centerIn: parent
                    width: Math.min(parent.width - 80, tiles.implicitWidth + 32)
                    height: tiles.implicitHeight + 32
                    chamfer: Appearance.chamfer.panel
                    fillColor: Theme.panel2

                    Flow {
                        id: tiles

                        anchors.centerIn: parent
                        width: Math.min(view.width - 112, view.count * 158 - 8)
                        spacing: 8

                        Repeater {
                            model: view.windows

                            Rectangle {
                                id: tile

                                required property var modelData
                                required property int index
                                readonly property bool sel: index === view.selected
                                readonly property string cls: modelData.lastIpcObject?.class ?? ""

                                width: 150
                                height: 70 + 42
                                color: sel ? Theme.alpha(Theme.accent, 0.08) : "transparent"
                                border.width: 1
                                border.color: sel ? Theme.accent : Theme.hair

                                Rectangle {
                                    id: preview

                                    x: 1
                                    y: 1
                                    width: parent.width - 2
                                    height: 70
                                    color: Theme.alpha(Theme.ground, 0.6)
                                    clip: true

                                    ScreencopyView {
                                        id: shot
                                        anchors.fill: parent
                                        captureSource: tile.modelData.wayland
                                        live: false
                                    }
                                    Timer {
                                        interval: 120
                                        running: !shot.hasContent
                                        repeat: true
                                        onTriggered: shot.captureFrame()
                                    }

                                    // The app's two-letter badge.
                                    Rectangle {
                                        anchors.left: parent.left
                                        anchors.bottom: parent.bottom
                                        anchors.margins: 5
                                        width: 22
                                        height: 16
                                        color: tile.sel ? Theme.accent : Theme.alpha(Theme.ground, 0.85)
                                        border.width: tile.sel ? 0 : 1
                                        border.color: Theme.hair

                                        Text {
                                            anchors.centerIn: parent
                                            text: (tile.cls.replace(/^.*\./, "") || "??").slice(0, 2).toUpperCase()
                                            color: tile.sel ? Theme.ground : Theme.text
                                            font.family: Appearance.font.data
                                            font.pixelSize: 9
                                            font.weight: Appearance.font.weightBold
                                            renderType: Text.NativeRendering
                                        }
                                    }
                                }

                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    y: 78
                                    elide: Text.ElideRight
                                    text: tile.modelData.title || tile.cls
                                    textFormat: Text.PlainText
                                    color: tile.sel ? Theme.bright : Theme.text
                                    font.family: Appearance.font.data
                                    font.pixelSize: 11
                                    renderType: Text.NativeRendering
                                }
                                Text {
                                    anchors.left: parent.left
                                    anchors.leftMargin: 8
                                    y: 96
                                    text: (tile.modelData.workspace?.id ?? 0) > 0 ? `WS ${tile.modelData.workspace.id}` : (tile.modelData.workspace?.name ?? "").replace(/^special:/, "").toUpperCase()
                                    color: Theme.dim
                                    font.family: Appearance.font.data
                                    font.pixelSize: 9
                                    font.letterSpacing: 9 * 0.12
                                    renderType: Text.NativeRendering
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
