import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// OVERVIEW (Super + Tab): the current page's five workspaces side by side,
// each window drawn where it actually is, from a low-rate live preview; the
// open special workspaces on a second row. Arrows move, Enter focuses, a
// window dragged onto another workspace moves there, Escape closes.
//
// **Previews exist only while it is open.** Everything is inside a Loader
// that is active only while shown, so closing destroys every capture at once;
// while open, each preview takes one frame a second, not a stream.
Variants {
    model: ShellState.screens

    PanelWindow {
        id: overlay

        required property ShellScreen modelData
        readonly property bool shown: ShellState.overviewOpen && ShellState.overlayScreen === modelData?.name

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

        onShownChanged: if (shown) Hyprland.refreshToplevels()

        Loader {
            anchors.fill: parent
            active: overlay.shown
            sourceComponent: Item {
                id: view

                readonly property var monitor: Hyprland.monitorFor(overlay.modelData)
                readonly property var mon: monitor?.lastIpcObject ?? ({})
                readonly property real monX: mon.x ?? 0
                readonly property real monY: mon.y ?? 0
                readonly property real monW: (mon.width ?? overlay.width) / (mon.scale ?? 1)
                readonly property real monH: (mon.height ?? overlay.height) / (mon.scale ?? 1)
                readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
                readonly property int pageStart: Math.floor(Math.max(0, activeId - 1) / Spaces.perPage) * Spaces.perPage + 1

                // The workspaces shown: five numbered, then any open specials.
                readonly property var numbered: [0, 1, 2, 3, 4].map(i => ({ key: `${pageStart + i}`, id: pageStart + i, label: `${pageStart + i}` }))
                readonly property var specials: (Hyprland.workspaces?.values ?? []).filter(w => w && w.id < 0 && (w.lastIpcObject?.windows ?? 0) > 0).map(w => ({ key: w.name, id: w.id, label: w.name.replace(/^special:/, "").toUpperCase() }))

                // Windows by workspace id, each [{ toplevel, x, y, w, h }].
                function windowsOf(id: int): var {
                    return (Hyprland.toplevels?.values ?? []).filter(t => t?.workspace?.id === id && t.lastIpcObject?.at).map(t => ({
                        toplevel: t,
                        x: (t.lastIpcObject.at[0] - monX) / monW,
                        y: (t.lastIpcObject.at[1] - monY) / monH,
                        w: t.lastIpcObject.size[0] / monW,
                        h: t.lastIpcObject.size[1] / monH
                    })).sort((a, b) => a.y - b.y || a.x - b.x);
                }

                // A flat list of every shown window, for the arrow keys.
                readonly property var allWindows: numbered.concat(specials).reduce((out, ws) => out.concat(windowsOf(ws.id).map(w => ({ ws: ws.id, address: w.toplevel.address }))), [])
                property int selected: Math.max(0, allWindows.findIndex(w => w.address === Hyprland.activeToplevel?.address))
                readonly property string selectedAddress: allWindows[selected]?.address ?? ""

                function focusSelected(): void {
                    const a = selectedAddress;
                    ShellState.overviewOpen = false;
                    if (a !== "")
                        Hyprland.dispatch(`hl.dsp.focus({ window = "address:0x${a}" })`);
                }
                function moveWindow(address: string, ws: int): void {
                    Hyprland.dispatch(`hl.dsp.window.move({ workspace = ${ws}, window = "address:0x${address}" })`);
                    refreshSoon.restart();
                }
                Timer {
                    id: refreshSoon
                    interval: 120
                    onTriggered: Hyprland.refreshToplevels()
                }

                // The wallpaper, blurred and darkened to about 35%.
                Wallpaper {
                    anchors.fill: parent
                    blurRadius: 16
                    dim: 0.65
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: ShellState.overviewOpen = false
                }

                Column {
                    id: head

                    x: 60
                    y: 48
                    spacing: 8

                    Row {
                        spacing: 10
                        GlitchText {
                            id: overTitle
                            text: "OVERVIEW"
                            pixelSize: 22
                        }
                        KanaTag {
                            anchors.verticalCenter: overTitle.verticalCenter
                            text: "一覧"
                            title: overTitle
                        }
                    }
                    Text {
                        text: "ARROWS MOVE · ENTER FOCUSES · DRAG A WINDOW TO ANOTHER WORKSPACE · ESC CLOSES"
                        color: Theme.dim
                        font.family: Appearance.font.data
                        font.pixelSize: 9
                        font.letterSpacing: 9 * 0.12
                        renderType: Text.NativeRendering
                    }
                }

                readonly property real cardW: (width - 120 - 4 * 16) / 5
                readonly property real cardH: cardW * monH / Math.max(1, monW)

                component Card: Item {
                    id: card

                    required property var ws
                    readonly property bool current: ws.id === view.activeId
                    readonly property var wins: view.windowsOf(ws.id)

                    width: view.cardW
                    height: view.cardH + 22

                    Text {
                        anchors.left: parent.left
                        text: card.ws.label
                        color: card.current ? Theme.accent : Theme.text
                        font.family: Appearance.font.data
                        font.pixelSize: 11
                        font.weight: Appearance.font.weightSemi
                        font.letterSpacing: 11 * 0.12
                        renderType: Text.NativeRendering
                    }
                    Text {
                        anchors.right: parent.right
                        text: card.wins.length === 1 ? "1 WINDOW" : `${card.wins.length} WINDOWS`
                        color: Theme.dim
                        font.family: Appearance.font.data
                        font.pixelSize: 9
                        font.letterSpacing: 9 * 0.12
                        renderType: Text.NativeRendering
                    }

                    Rectangle {
                        id: frame

                        y: 22
                        width: parent.width
                        height: view.cardH
                        color: Theme.alpha(Theme.ground, 0.6)
                        border.width: 1
                        border.color: card.current ? Theme.accent : Theme.hair
                        clip: true

                        // Clicking an empty spot goes to that workspace.
                        TapHandler {
                            onTapped: {
                                ShellState.overviewOpen = false;
                                Hyprland.dispatch(card.ws.id > 0 ? `hl.dsp.focus({ workspace = ${card.ws.id} })` : `hl.dsp.workspace.toggle_special("${card.ws.label.toLowerCase()}")`);
                            }
                        }

                        Repeater {
                            model: card.wins

                            Rectangle {
                                id: win

                                required property var modelData
                                readonly property string address: modelData.toplevel.address
                                readonly property bool sel: address === view.selectedAddress

                                x: modelData.x * frame.width
                                y: modelData.y * frame.height
                                width: Math.max(8, modelData.w * frame.width)
                                height: Math.max(8, modelData.h * frame.height)
                                color: sel ? Theme.alpha(Theme.accent, 0.12) : Theme.panel2
                                border.width: 1
                                border.color: sel ? Theme.accent : Theme.hair
                                z: drag.active ? 10 : 0

                                ScreencopyView {
                                    id: shot

                                    anchors.fill: parent
                                    anchors.margins: 1
                                    captureSource: win.modelData.toplevel.wayland
                                    live: false
                                    opacity: win.sel ? 0.85 : 1
                                }
                                // A low rate: one frame a second, and only while
                                // open. The first comes once the capture context
                                // is ready rather than at creation.
                                Timer {
                                    interval: shot.hasContent ? 1000 : 150
                                    repeat: true
                                    running: true
                                    onTriggered: shot.captureFrame()
                                }

                                DragHandler {
                                    id: drag
                                    onActiveChanged: {
                                        if (active)
                                            return;
                                        const p = win.mapToItem(view, win.width / 2, win.height / 2);
                                        const target = view.cardAt(p.x, p.y);
                                        if (target !== null && target !== card.ws.id)
                                            view.moveWindow(win.address, target);
                                        win.x = Qt.binding(() => win.modelData.x * frame.width);
                                        win.y = Qt.binding(() => win.modelData.y * frame.height);
                                    }
                                }
                                TapHandler {
                                    onTapped: {
                                        view.selected = view.allWindows.findIndex(w => w.address === win.address);
                                        view.focusSelected();
                                    }
                                }
                            }
                        }
                    }
                }

                // Which workspace card is under a point, by id; null if none.
                function cardAt(px: real, py: real): var {
                    for (const r of [row1, row2]) {
                        for (let i = 0; i < r.children.length; i++) {
                            const c = r.children[i];
                            if (!c.ws)
                                continue;
                            const p = c.mapToItem(view, 0, 0);
                            if (px >= p.x && px <= p.x + c.width && py >= p.y && py <= p.y + c.height)
                                return c.ws.id;
                        }
                    }
                    return null;
                }

                Row {
                    id: row1

                    x: 60
                    anchors.top: head.bottom
                    anchors.topMargin: 36
                    spacing: 16

                    Repeater {
                        model: view.numbered
                        Card {
                            required property var modelData
                            ws: modelData
                        }
                    }
                }
                Row {
                    id: row2

                    x: 60
                    anchors.top: row1.bottom
                    anchors.topMargin: 28
                    spacing: 16
                    visible: view.specials.length > 0

                    Repeater {
                        model: view.specials
                        Card {
                            required property var modelData
                            ws: modelData
                        }
                    }
                }

                OverlayKeys {
                    anchors.fill: parent
                    active: overlay.shown
                    onEscaped: ShellState.overviewOpen = false
                    Keys.onLeftPressed: view.selected = Math.max(0, view.selected - 1)
                    Keys.onRightPressed: view.selected = Math.min(view.allWindows.length - 1, view.selected + 1)
                    Keys.onUpPressed: view.selected = Math.max(0, view.selected - 1)
                    Keys.onDownPressed: view.selected = Math.min(view.allWindows.length - 1, view.selected + 1)
                    Keys.onReturnPressed: view.focusSelected()
                    Keys.onEnterPressed: view.focusSelected()
                }
            }
        }
    }
}
