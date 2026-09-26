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
                readonly property int page: Math.floor(Math.max(0, activeId - 1) / Spaces.perPage)
                readonly property int pageStart: page * Spaces.perPage + 1

                readonly property var numbered: [0, 1, 2, 3, 4].map(i => ({ id: pageStart + i, label: `${pageStart + i}` }))
                readonly property var specials: (Hyprland.workspaces?.values ?? []).filter(w => w && w.id < 0 && (w.lastIpcObject?.windows ?? 0) > 0).map(w => ({ id: w.id, name: w.name.replace(/^special:/, ""), label: w.name.replace(/^special:/, "").toUpperCase() }))

                function windowsOf(id: int): var {
                    return (Hyprland.toplevels?.values ?? []).filter(t => t?.workspace?.id === id && t.lastIpcObject?.at).map(t => ({
                        toplevel: t,
                        x: (t.lastIpcObject.at[0] - monX) / monW,
                        y: (t.lastIpcObject.at[1] - monY) / monH,
                        w: t.lastIpcObject.size[0] / monW,
                        h: t.lastIpcObject.size[1] / monH
                    })).sort((a, b) => a.y - b.y || a.x - b.x);
                }

                readonly property var allWindows: numbered.reduce((out, ws) => out.concat(windowsOf(ws.id).map(w => ({ ws: ws.id, toplevel: w.toplevel, address: w.toplevel.address }))), [])
                property int selected: Math.max(0, allWindows.findIndex(w => w.address === Hyprland.activeToplevel?.address))
                readonly property string selectedAddress: allWindows[selected]?.address ?? ""

                function focusSelected(): void {
                    const w = allWindows[selected];
                    ShellState.overviewOpen = false;
                    if (w)
                        Switcher.focusWindow(w.toplevel);
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

                // The wallpaper, blurred and darkened to about 30%.
                Wallpaper {
                    anchors.fill: parent
                    blurRadius: 16
                    dim: 0.7
                }
                MouseArea {
                    anchors.fill: parent
                    onClicked: ShellState.overviewOpen = false
                }

                readonly property real margin: 60
                readonly property real gap: 20
                readonly property real cardW: (width - 2 * margin - 2 * gap) / 3
                readonly property real previewH: Math.min(cardW * monH / Math.max(1, monW), (height - 200 - 2 * 34 - gap) / 2)

                Column {
                    id: head

                    x: view.margin
                    y: 44
                    spacing: 8

                    Row {
                        spacing: 10
                        // The full-screen BackControl: does what Escape does.
                        BackButton {
                            anchors.verticalCenter: overTitle.verticalCenter
                            onActivated: ShellState.overviewOpen = false
                        }
                        GlitchText {
                            id: overTitle
                            text: "OVERVIEW"
                            // The full-screen view title role (DESIGN.md): 22 px, 0.12em.
                            pixelSize: Tokens.type.viewTitle.size
                            tracking: Tokens.type.viewTitle.tracking
                        }
                        KanaTag {
                            anchors.verticalCenter: overTitle.verticalCenter
                            text: "一覧"
                            title: overTitle
                        }
                        Text {
                            anchors.verticalCenter: overTitle.verticalCenter
                            text: `PAGE ${view.page + 1} · WORKSPACES ${view.pageStart}–${view.pageStart + 4}`
                            color: Tokens.color.text
                            font.family: Tokens.font.data
                            font.pixelSize: 10
                            font.letterSpacing: 10 * 0.14
                            renderType: Text.NativeRendering
                        }
                    }
                    Text {
                        text: "ARROWS MOVE · ENTER FOCUSES · DRAG A WINDOW TO ANOTHER WORKSPACE · ESC CLOSES"
                        color: Tokens.color.dim
                        font.family: Tokens.font.data
                        font.pixelSize: 9
                        font.letterSpacing: 9 * 0.12
                        renderType: Text.NativeRendering
                    }
                }

                component Card: Item {
                    id: card

                    required property var ws
                    readonly property bool current: ws.id === view.activeId
                    readonly property var wins: view.windowsOf(ws.id)

                    width: view.cardW
                    height: view.previewH + 30

                    Text {
                        anchors.left: parent.left
                        text: card.ws.label
                        color: card.current ? Tokens.color.accent : Tokens.color.bright
                        font.family: Tokens.font.display
                        font.pixelSize: 14
                        font.weight: Appearance.font.weightBold
                        renderType: Text.NativeRendering
                    }
                    Text {
                        anchors.right: parent.right
                        y: 3
                        text: card.wins.length === 1 ? "1 WINDOW" : `${card.wins.length} WINDOWS`
                        color: Tokens.color.dim
                        font.family: Tokens.font.data
                        font.pixelSize: 9
                        font.letterSpacing: 9 * 0.12
                        renderType: Text.NativeRendering
                    }

                    Rectangle {
                        id: frame

                        y: 26
                        width: parent.width
                        height: view.previewH
                        color: Theme.alpha(Tokens.color.ground, 0.6)
                        border.width: 1
                        border.color: card.current ? Tokens.color.accent : Tokens.color.hair
                        clip: true

                        Text {
                            anchors.centerIn: parent
                            visible: card.wins.length === 0
                            text: "EMPTY"
                            color: Tokens.color.mute
                            font.family: Tokens.font.data
                            font.pixelSize: 10
                            font.letterSpacing: 10 * 0.18
                            renderType: Text.NativeRendering
                        }

                        // Clicking an empty spot goes to that workspace.
                        TapHandler {
                            onTapped: {
                                ShellState.overviewOpen = false;
                                Switcher.focusWorkspace(card.ws.id);
                            }
                        }

                        Repeater {
                            model: card.wins

                            Rectangle {
                                id: win

                                required property var modelData
                                readonly property string address: modelData.toplevel.address
                                readonly property bool sel: address === view.selectedAddress
                                readonly property string cls: modelData.toplevel.lastIpcObject?.class ?? ""

                                x: modelData.x * frame.width
                                y: modelData.y * frame.height
                                width: Math.max(12, modelData.w * frame.width)
                                height: Math.max(12, modelData.h * frame.height)
                                color: Tokens.color.panel2
                                border.width: 1
                                border.color: sel ? Tokens.color.accent : Tokens.color.hair
                                clip: true
                                z: drag.active ? 10 : 0

                                // The window itself, one frame a second while open.
                                ScreencopyView {
                                    id: shot
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    captureSource: win.modelData.toplevel.wayland
                                    live: false
                                    opacity: 0.55
                                }
                                Timer {
                                    interval: shot.hasContent ? 1000 : 150
                                    repeat: true
                                    running: true
                                    onTriggered: shot.captureFrame()
                                }
                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    color: win.sel ? Theme.alpha(Tokens.color.accent, 0.14) : "transparent"
                                }
                                // Its badge and title.
                                Row {
                                    x: 6
                                    y: 6
                                    spacing: 6
                                    width: parent.width - 12
                                    AppBadge {
                                        size: 20
                                        pixelSize: 9
                                        name: win.cls
                                        selected: win.sel
                                    }
                                    Text {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: parent.width - 26
                                        elide: Text.ElideRight
                                        text: win.modelData.toplevel.title || win.cls
                                        textFormat: Text.PlainText
                                        color: win.sel ? Tokens.color.bright : Tokens.color.text
                                        font.family: Tokens.font.data
                                        font.pixelSize: 10
                                        renderType: Text.NativeRendering
                                    }
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

                function cardAt(px: real, py: real): var {
                    for (let i = 0; i < grid.children.length; i++) {
                        const c = grid.children[i];
                        if (!c.ws)
                            continue;
                        const p = c.mapToItem(view, 0, 0);
                        if (px >= p.x && px <= p.x + c.width && py >= p.y && py <= p.y + c.height)
                            return c.ws.id;
                    }
                    return null;
                }

                // Three per row: the page's five workspaces, then the open
                // special workspaces as chips in the sixth place.
                Grid {
                    id: grid

                    x: view.margin
                    anchors.top: head.bottom
                    anchors.topMargin: 28
                    columns: 3
                    columnSpacing: view.gap
                    rowSpacing: view.gap

                    Repeater {
                        model: view.numbered
                        Card {
                            required property var modelData
                            ws: modelData
                        }
                    }

                    Item {
                        width: view.cardW
                        height: view.previewH + 30

                        Text {
                            text: "SPECIAL"
                            color: Tokens.color.dim
                            font.family: Tokens.font.data
                            font.pixelSize: 9
                            font.letterSpacing: 9 * 0.18
                            renderType: Text.NativeRendering
                        }
                        Flow {
                            y: 26
                            width: parent.width
                            spacing: 8
                            Repeater {
                                model: view.specials
                                Rectangle {
                                    id: chip
                                    required property var modelData
                                    width: chipText.implicitWidth + 24
                                    height: 26
                                    color: chipHover.hovered ? Theme.cell : Theme.alpha(Tokens.color.ground, 0.6)
                                    border.width: 1
                                    border.color: Tokens.color.hair
                                    Text {
                                        id: chipText
                                        anchors.centerIn: parent
                                        text: `${chip.modelData.label} · ${view.windowsOf(chip.modelData.id).length}`
                                        color: Tokens.color.text
                                        font.family: Tokens.font.data
                                        font.pixelSize: 10
                                        font.letterSpacing: 10 * 0.14
                                        renderType: Text.NativeRendering
                                    }
                                    HoverHandler {
                                        id: chipHover
                                        cursorShape: Qt.PointingHandCursor
                                    }
                                    TapHandler {
                                        onTapped: {
                                            ShellState.overviewOpen = false;
                                            Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${chip.modelData.name}")`);
                                        }
                                    }
                                }
                            }
                        }
                        Text {
                            y: 30
                            visible: view.specials.length === 0
                            text: "NONE OPEN"
                            color: Tokens.color.mute
                            font.family: Tokens.font.data
                            font.pixelSize: 9
                            font.letterSpacing: 9 * 0.18
                            renderType: Text.NativeRendering
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
