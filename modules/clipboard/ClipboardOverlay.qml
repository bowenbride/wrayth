import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services
import qs.utils

// CLIPBOARD (Super + Shift + V): the history, newest first with pinned entries
// on top -- a filter, then each entry's text or image, what it is and how old,
// PIN and delete. Enter puts the chosen one back on the clipboard and pastes it
// into the window that was focused before this opened. In the launcher's
// shape, on the focused screen.
Variants {
    model: ShellState.screens

    PanelWindow {
        id: overlay

        required property ShellScreen modelData
        readonly property bool shown: ShellState.clipboardOpen && ShellState.overlayScreen === modelData?.name

        property string filter: ""
        property int selected: 0
        readonly property var rows: Clipboard.ordered.filter(e => overlay.filter === ""
            || (e.kind === "text" ? e.preview.toLowerCase().includes(overlay.filter) : "image".includes(overlay.filter)))
        property real now: Date.now()

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

        onShownChanged: {
            if (!shown)
                return;
            // Where Enter will paste: the window focused before this opened.
            Clipboard.pasteInto = ActiveWindow.ipc?.address ?? "";
            input.text = "";
            selected = 0;
            lastPointer = null;
            now = Date.now();
            input.forceActiveFocus();
        }
        onRowsChanged: selected = Math.max(0, Math.min(selected, rows.length - 1))

        // The pointer picks a row only when it moves: one resting where the
        // list opens (or where rows scroll past it) leaves the keys in charge.
        property var lastPointer: null
        function pointerAt(p: point, index: int): void {
            if (lastPointer && (p.x !== lastPointer.x || p.y !== lastPointer.y))
                selected = index;
            lastPointer = Qt.point(p.x, p.y);
        }

        function move(delta: int): void {
            if (rows.length > 0)
                selected = (selected + delta + rows.length) % rows.length;
        }
        function choose(): void {
            const e = rows[selected];
            if (!e)
                return;
            ShellState.clipboardOpen = false;
            Clipboard.use(e.key, true);
        }

        function removeSelected(): void {
            const e = rows[selected];
            if (e)
                Clipboard.remove(e.key);
        }
        function pinSelected(): void {
            const e = rows[selected];
            if (e)
                Clipboard.togglePin(e.key);
        }
        // "JUST NOW", "2 MIN AGO", "3 H AGO", "2 D AGO".
        function ageText(t: real): string {
            const s = Math.max(0, (overlay.now - t) / 1000);
            if (s < 60)
                return "JUST NOW";
            if (s < 3600)
                return `${Math.floor(s / 60)} MIN AGO`;
            if (s < 86400)
                return `${Math.floor(s / 3600)} H AGO`;
            return `${Math.floor(s / 86400)} D AGO`;
        }

        function kindOf(e: var): string {
            if (e.kind === "image")
                return "IMAGE";
            return /^\s*(https?|ftp):\/\/\S+\s*$/i.test(e.preview) ? "LINK" : "TEXT";
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.45
        }
        MouseArea {
            anchors.fill: parent
            onClicked: ShellState.clipboardOpen = false
        }

        // **520 px, centred on its screen, and always the same height**: the
        // list is sized for seven rows whatever the filter leaves, so the
        // panel never moves or resizes while you type.
        ChamferPanel {
            id: panel

            readonly property int rowHeight: 40
            readonly property int visibleRows: 7

            anchors.centerIn: parent
            width: 520
            height: header.height + search.height + 10 + list.height + footer.height
            chamfer: Appearance.chamfer.panel
            fillColor: Theme.panel2

            MouseArea {
                anchors.fill: parent
            }

            // --- Header: CLIPBOARD 記憶 ........ N ITEMS · MEMORY ONLY ---------
            Item {
                id: header

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 48

                GlitchText {
                    id: clipTitle

                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CLIPBOARD"
                    pixelSize: 18
                }
                KanaTag {
                    anchors.left: clipTitle.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "記憶"
                    title: clipTitle
                }
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        const n = Clipboard.entries.length;
                        const mode = { memory: "MEMORY ONLY", disk: "SAVED TO DISK", off: "HISTORY OFF" }[Clipboard.history];
                        return `${n} ${n === 1 ? "ITEM" : "ITEMS"} · ${mode}`;
                    }
                    color: Theme.dim
                    font.family: Appearance.font.data
                    font.pixelSize: 9
                    font.letterSpacing: 9 * 0.12
                    renderType: Text.NativeRendering
                }
            }

            // --- The filter: 28 px, accent frame, a free-text caret ------------
            Rectangle {
                id: search

                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 16
                anchors.rightMargin: 16
                height: 28
                color: "transparent"
                border.width: 1
                border.color: Theme.accent

                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: "Type to filter…"
                    color: Theme.dim
                    font.family: Appearance.font.data
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                }
                TextInput {
                    id: input

                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.bright
                    selectionColor: Theme.alpha(Theme.accent, 0.35)
                    selectedTextColor: Theme.bright
                    font.family: Appearance.font.data
                    font.pixelSize: 11
                    renderType: Text.NativeRendering
                    cursorDelegate: Rectangle {
                        width: 1
                        color: Theme.accent
                    }

                    onTextChanged: overlay.filter = text.trim().toLowerCase()
                    Keys.onUpPressed: overlay.move(-1)
                    Keys.onDownPressed: overlay.move(1)
                    Keys.onReturnPressed: overlay.choose()
                    Keys.onEnterPressed: overlay.choose()
                    Keys.onEscapePressed: ShellState.clipboardOpen = false
                    Keys.onDeletePressed: event => {
                        // Delete removes the selected entry; with text typed
                        // and the caret before its end, it edits the filter.
                        if (input.text === "" || input.cursorPosition >= input.text.length)
                            overlay.removeSelected();
                        else
                            event.accepted = false;
                    }
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier)) {
                            overlay.pinSelected();
                            event.accepted = true;
                        }
                    }
                }
            }

            // --- The entries -----------------------------------------------------
            Flickable {
                id: list

                anchors.top: search.bottom
                anchors.topMargin: 10
                anchors.left: parent.left
                anchors.right: parent.right
                height: panel.rowHeight * panel.visibleRows
                contentHeight: entries.implicitHeight
                contentY: Math.max(0, Math.min(contentHeight - height, (overlay.selected + 1) * panel.rowHeight - height))
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Behavior on contentY {
                    NumberAnimation {
                        duration: Appearance.duration.move
                        easing.type: Easing.OutCubic
                    }
                }

                Text {
                    visible: overlay.rows.length === 0
                    x: 16
                    y: 14
                    text: Clipboard.history === "off" ? "HISTORY IS OFF · TURN IT ON UNDER PRIVACY IN THE PROFILE PICKER"
                        : (Clipboard.entries.length === 0 ? "NOTHING COPIED YET" : "NOTHING MATCHES")
                    color: Theme.dim
                    font.family: Appearance.font.data
                    font.pixelSize: 10
                    font.letterSpacing: 10 * 0.12
                    renderType: Text.NativeRendering
                }

                Column {
                    id: entries

                    width: list.width

                    Repeater {
                        model: overlay.rows

                        Item {
                            id: row

                            required property var modelData
                            required property int index
                            readonly property bool current: index === overlay.selected
                            readonly property bool image: modelData.kind === "image"

                            width: entries.width
                            height: panel.rowHeight

                            // Selected: a subtle dark fill and a 2 px accent edge.
                            Rectangle {
                                anchors.fill: parent
                                color: Theme.alpha(Theme.ground, 0.55)
                                opacity: row.current ? 1 : 0
                                Behavior on opacity {
                                    NumberAnimation {
                                        duration: Appearance.duration.state
                                        easing.type: Easing.OutCubic
                                    }
                                }
                            }
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 2
                                color: Theme.accent
                                opacity: row.current ? 1 : 0
                            }

                            // An image: a 54 x 30 thumbnail in a hairline frame.
                            Rectangle {
                                id: thumb

                                visible: row.image
                                x: 16
                                anchors.verticalCenter: parent.verticalCenter
                                width: 54
                                height: 30
                                color: "transparent"
                                border.width: 1
                                border.color: Theme.hair

                                Image {
                                    anchors.fill: parent
                                    anchors.margins: 1
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    sourceSize.height: 60
                                    // From the stored file, decoded at thumbnail size.
                                    source: !row.image || !overlay.shown ? "" : Clipboard.isFile(row.modelData) ? `file://${row.modelData.data}` : `data:${row.modelData.mime};base64,${row.modelData.data}`
                                }
                            }

                            // The text (one line, cut with an ellipsis) and the meta line.
                            Column {
                                anchors.left: row.image ? thumb.right : parent.left
                                anchors.leftMargin: row.image ? 10 : 16
                                anchors.right: pin.left
                                anchors.rightMargin: 12
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2

                                Text {
                                    visible: !row.image
                                    width: parent.width
                                    elide: Text.ElideRight
                                    maximumLineCount: 1
                                    textFormat: Text.PlainText
                                    text: row.image ? "" : row.modelData.preview.replace(/\s+/g, " ")
                                    color: row.current ? Theme.bright : Theme.text
                                    font.family: Appearance.font.data
                                    font.pixelSize: 11
                                    renderType: Text.NativeRendering
                                }
                                Text {
                                    width: parent.width
                                    elide: Text.ElideRight
                                    text: `${overlay.kindOf(row.modelData)} · ${overlay.ageText(row.modelData.time)}`
                                    color: Theme.dim
                                    font.family: Appearance.font.data
                                    font.pixelSize: 9
                                    font.letterSpacing: 9 * 0.1
                                    renderType: Text.NativeRendering
                                }
                            }

                            // PIN / PINNED: a 20 px chip, as wide as PINNED either way.
                            Rectangle {
                                id: pin

                                anchors.right: del.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: pinReserve.implicitWidth + 16
                                height: 20
                                color: row.modelData.pinned ? Theme.alpha(Theme.accent, 0.12) : "transparent"
                                border.width: 1
                                border.color: row.modelData.pinned ? Theme.accent : Theme.hair

                                Text {
                                    id: pinReserve

                                    visible: false
                                    text: "PINNED"
                                    font: pinText.font
                                }
                                Text {
                                    id: pinText

                                    anchors.centerIn: parent
                                    text: row.modelData.pinned ? "PINNED" : "PIN"
                                    color: row.modelData.pinned ? Theme.accent : (pinHover.hovered ? Theme.text : Theme.dim)
                                    font.family: Appearance.font.data
                                    font.pixelSize: 9
                                    font.letterSpacing: 9 * 0.12
                                    renderType: Text.NativeRendering
                                }
                                HoverHandler {
                                    id: pinHover
                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler {
                                    onTapped: Clipboard.togglePin(row.modelData.key)
                                }
                            }

                            // Delete: a 20 x 20 control showing a minus.
                            Item {
                                id: del

                                anchors.right: parent.right
                                anchors.rightMargin: 14
                                anchors.verticalCenter: parent.verticalCenter
                                width: 20
                                height: 20

                                MinusGlyph {
                                    anchors.fill: parent
                                    inset: 5
                                    thickness: 1.5
                                    color: delHover.hovered ? Theme.accent : Theme.dim
                                }
                                HoverHandler {
                                    id: delHover
                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler {
                                    onTapped: Clipboard.remove(row.modelData.key)
                                }
                            }

                            HoverHandler {
                                onPointChanged: if (hovered) overlay.pointerAt(point.scenePosition, row.index)
                            }
                            TapHandler {
                                onTapped: {
                                    overlay.selected = row.index;
                                    overlay.choose();
                                }
                            }
                        }
                    }
                }
            }

            // --- Footer ----------------------------------------------------------
            Item {
                id: footer

                anchors.top: list.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 34

                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    height: Appearance.metrics.hairline
                    color: Theme.hair
                }
                Text {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ENTER PASTES · PINNED STAY AT THE TOP"
                    color: Theme.dim
                    font.family: Appearance.font.data
                    font.pixelSize: 9
                    font.letterSpacing: 9 * 0.12
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
