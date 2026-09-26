import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// KEYBINDS (Super + /): every bind Hyprland has, grouped SHELL, WINDOWS,
// WORKSPACES and MEDIA AND CAPTURE, read from Hyprland itself each time it
// opens. Wrayth's own can be moved: click the keys, press the new ones. Yours
// are listed, marked FROM YOUR CONFIG, and changed there.
Variants {
    model: ShellState.screens

    PanelWindow {
        id: overlay

        required property ShellScreen modelData
        readonly property bool shown: ShellState.keybindsOpen && ShellState.overlayScreen === modelData?.name

        // The bind being given new keys, and what happened when it was.
        // `pending`: { id, keys, holder, kind: "swap" | "theirs" | "strand" }.
        property string capturing: ""
        property var pending: null
        property string filter: ""
        // For the Super tap: set when Super goes down, cleared by any other key.
        property bool superAlone: false

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
            if (shown) {
                capturing = "";
                pending = null;
                search.text = "";
                Keybinds.refresh();
                keys.take();
            } else {
                stopCapture();
            }
        }

        function startCapture(id: string): void {
            pending = null;
            capturing = id;
            superAlone = false;
            Keybinds.beginCapture();
            keys.take();
        }
        function stopCapture(): void {
            capturing = "";
            Keybinds.endCapture();
        }

        onPendingChanged: ShellState.keybindPending = pending ? pending.kind : ""
        Connections {
            target: ShellState
            function onKeybindCapture(id: string): void {
                if (overlay.shown)
                    overlay.startCapture(id);
            }
            function onKeybindAnswer(yes: bool): void {
                if (!overlay.shown || !overlay.pending)
                    return;
                const p = overlay.pending;
                overlay.pending = null;
                if (!yes)
                    return;
                if (p.kind === "swap")
                    Keybinds.swap(p.id, p.keys);
                else if (p.kind === "strand")
                    Keybinds.setKeys(p.id, "");
            }
        }

        // Escape is the capture submap's one bind: it ends the submap, and the
        // overlay hears that rather than the key.
        Connections {
            target: Hyprland
            function onRawEvent(event: HyprlandEvent): void {
                if (event.name === "submap" && event.data === "" && overlay.capturing !== "") {
                    overlay.capturing = "";
                    Keybinds.capturing = false;
                }
            }
        }

        // Qt's key to the name Hyprland binds it by.
        function keyName(key: int, text: string): string {
            if (key >= Qt.Key_A && key <= Qt.Key_Z)
                return String.fromCharCode(key);
            if (key >= Qt.Key_0 && key <= Qt.Key_9)
                return String.fromCharCode(key);
            if (key >= Qt.Key_F1 && key <= Qt.Key_F24)
                return `F${key - Qt.Key_F1 + 1}`;
            const named = {
                [Qt.Key_Space]: "space", [Qt.Key_Return]: "Return", [Qt.Key_Enter]: "Return", [Qt.Key_Tab]: "Tab",
                [Qt.Key_Backtab]: "Tab", [Qt.Key_Backspace]: "BackSpace", [Qt.Key_Delete]: "Delete",
                [Qt.Key_Insert]: "Insert", [Qt.Key_Home]: "Home", [Qt.Key_End]: "End", [Qt.Key_PageUp]: "Prior",
                [Qt.Key_PageDown]: "Next", [Qt.Key_Left]: "left", [Qt.Key_Right]: "right", [Qt.Key_Up]: "up",
                [Qt.Key_Down]: "down", [Qt.Key_Print]: "Print", [Qt.Key_Slash]: "slash", [Qt.Key_Question]: "question",
                [Qt.Key_Comma]: "comma", [Qt.Key_Period]: "period", [Qt.Key_Minus]: "minus", [Qt.Key_Equal]: "equal",
                [Qt.Key_BracketLeft]: "bracketleft", [Qt.Key_BracketRight]: "bracketright", [Qt.Key_Semicolon]: "semicolon",
                [Qt.Key_Apostrophe]: "apostrophe", [Qt.Key_QuoteLeft]: "grave", [Qt.Key_Backslash]: "backslash",
                [Qt.Key_MediaPlay]: "XF86AudioPlay", [Qt.Key_MediaTogglePlayPause]: "XF86AudioPlay",
                [Qt.Key_MediaPause]: "XF86AudioPause", [Qt.Key_MediaNext]: "XF86AudioNext",
                [Qt.Key_MediaPrevious]: "XF86AudioPrev", [Qt.Key_VolumeUp]: "XF86AudioRaiseVolume",
                [Qt.Key_VolumeDown]: "XF86AudioLowerVolume", [Qt.Key_VolumeMute]: "XF86AudioMute",
                [Qt.Key_MonBrightnessUp]: "XF86MonBrightnessUp", [Qt.Key_MonBrightnessDown]: "XF86MonBrightnessDown"
            };
            return named[key] ?? (text && text.length === 1 && text.charCodeAt(0) > 32 ? text : "");
        }
        function modsOf(modifiers: int): var {
            const out = [];
            if (modifiers & Qt.MetaModifier)
                out.push("SUPER");
            if (modifiers & Qt.ControlModifier)
                out.push("CTRL");
            if (modifiers & Qt.AltModifier)
                out.push("ALT");
            if (modifiers & Qt.ShiftModifier)
                out.push("SHIFT");
            return out;
        }

        // A combination pressed: apply it, or ask.
        function chose(id: string, keys: string): void {
            stopCapture();
            if (keys === "") {
                if (Keybinds.strands(id, "")) {
                    pending = { id: id, keys: "", holder: null, kind: "strand" };
                    return;
                }
                Keybinds.setKeys(id, "");
                return;
            }
            const holder = Keybinds.holderOf(keys, id);
            if (!holder) {
                Keybinds.setKeys(id, keys);
                return;
            }
            pending = { id: id, keys: keys, holder: holder, kind: holder.ours ? "swap" : "theirs" };
        }

        // --- The backdrop: the wallpaper, blurred and darkened, like the picker --
        Wallpaper {
            anchors.fill: parent
            blurRadius: 16
            dim: 0.65
        }
        MouseArea {
            anchors.fill: parent
            onClicked: {
                if (overlay.capturing !== "")
                    overlay.stopCapture();
                else if (overlay.pending)
                    overlay.pending = null;
                else
                    ShellState.keybindsOpen = false;
            }
        }

        readonly property real span: Math.min(1640, width - 96)
        readonly property real originX: Math.round((width - span) / 2)
        readonly property var groups: ["SHELL", "WINDOWS", "WORKSPACES", "MEDIA AND CAPTURE", "FROM YOUR CONFIG"]
        readonly property real gap: 24
        readonly property real columnWidth: Math.floor((span - gap * (groups.length - 1)) / groups.length)

        // The full-screen header row: BackControl, title, search.
        BackButton {
            id: back
            x: overlay.originX
            y: 118 + Math.round((40 - height) / 2)
            onActivated: ShellState.keybindsOpen = false
        }

        // --- Header: KEYBINDS 操作, the search field on the right ----------------
        Item {
            id: header

            x: overlay.originX
            y: 118
            width: overlay.span
            height: 40

            Row {
                anchors.left: parent.left
                anchors.leftMargin: back.width + Tokens.space.s16
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                GlitchText {
                    id: keybindsTitle

                    anchors.verticalCenter: parent.verticalCenter
                    text: "KEYBINDS"
                    // The full-screen view title role (DESIGN.md): 22 px, 0.12em.
                    pixelSize: Tokens.type.viewTitle.size
                    tracking: Tokens.type.viewTitle.tracking
                }
                KanaTag {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "操作"
                    title: keybindsTitle
                }
            }

            // The filter: free text, so it keeps its caret.
            InputField {
                id: search

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 320
                height: 28
                placeholder: "SEARCH"
                onEdited: value => overlay.filter = value.trim().toLowerCase()
                onEscaped: keys.take()
            }
        }

        // --- The status line: capturing, or a question ---------------------------
        Item {
            id: status

            x: overlay.originX
            y: header.y + header.height + 10
            width: overlay.span
            height: 26

            component Label: Text {
                anchors.verticalCenter: parent.verticalCenter
                font.family: Tokens.font.data
                font.pixelSize: 10
                font.letterSpacing: 10 * 0.12
                renderType: Text.NativeRendering
            }

            Row {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Label {
                    visible: overlay.capturing === "" && !overlay.pending
                    color: Keybinds.busy ? Tokens.color.accent : Tokens.color.dim
                    text: Keybinds.busy ? "APPLYING" : "CLICK A KEY TO CHANGE IT · CHANGES APPLY AT ONCE"
                }
                Label {
                    visible: overlay.capturing !== ""
                    color: Tokens.color.accent
                    text: "PRESS THE NEW KEYS · ESCAPE CANCELS · DELETE REMOVES THE KEY"
                }
                Label {
                    visible: !!overlay.pending
                    color: Tokens.color.alert
                    text: {
                        const p = overlay.pending;
                        if (!p)
                            return "";
                        if (p.kind === "strand")
                            return p.id === "lock" ? "THE LOCKSCREEN WOULD HAVE NO KEY" : "THE POWER MENU WOULD HAVE NO KEY";
                        if (p.kind === "theirs")
                            return `${Keybinds.capsOf(p.keys).join(" + ")} · ALREADY USED BY ${String(p.holder?.label ?? "YOUR CONFIG").toUpperCase()} (FROM YOUR CONFIG)`;
                        return `${Keybinds.capsOf(p.keys).join(" + ")} · ALREADY USED BY ${p.holder.label.toUpperCase()}`;
                    }
                }
                ActionButton {
                    visible: !!overlay.pending && overlay.pending.kind === "swap"
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SWAP"
                    accented: true
                    onClicked: {
                        Keybinds.swap(overlay.pending.id, overlay.pending.keys);
                        overlay.pending = null;
                    }
                }
                ActionButton {
                    visible: !!overlay.pending && overlay.pending.kind === "strand"
                    anchors.verticalCenter: parent.verticalCenter
                    text: "REMOVE ANYWAY"
                    accented: true
                    onClicked: {
                        Keybinds.setKeys(overlay.pending.id, "");
                        overlay.pending = null;
                    }
                }
                ActionButton {
                    visible: !!overlay.pending
                    anchors.verticalCenter: parent.verticalCenter
                    text: "CANCEL"
                    onClicked: overlay.pending = null
                }
            }
        }

        // --- The columns: one per group, each scrolling on its own ---------------
        Row {
            id: columns

            x: overlay.originX
            y: status.y + status.height + 14
            height: overlay.height - y - 110
            spacing: overlay.gap

            Repeater {
                model: overlay.groups

                Item {
                    id: group

                    required property string modelData
                    readonly property bool mine: modelData === "FROM YOUR CONFIG"
                    readonly property var rows: Keybinds.binds.filter(b => (mine ? (!b.ours && !b.fixed) : ((b.ours || b.fixed) && b.group === modelData))
                        && (overlay.filter === "" || `${b.label} ${b.keys}`.toLowerCase().includes(overlay.filter)))

                    width: overlay.columnWidth
                    height: columns.height

                    // Header: 10 px, the data colour, 0.16em, a hairline under.
                    Text {
                        id: groupTitle

                        anchors.left: parent.left
                        anchors.top: parent.top
                        text: group.modelData
                        color: Tokens.color.signal
                        font.family: Tokens.font.data
                        font.pixelSize: 10
                        font.weight: Tokens.font.dataWeight
                        font.letterSpacing: 10 * 0.16
                        renderType: Text.NativeRendering
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: groupTitle.verticalCenter
                        text: `${group.rows.length}`
                        color: Tokens.color.dim
                        font.family: Tokens.font.data
                        font.pixelSize: 10
                        renderType: Text.NativeRendering
                    }
                    Rectangle {
                        id: groupRule

                        anchors.top: groupTitle.bottom
                        anchors.topMargin: 6
                        width: parent.width
                        height: Tokens.measure.hairline
                        color: Tokens.color.hair
                    }

                    // **Built eight rows a frame**, so a long list is never one stall.
                    ListModel {
                        id: shown
                    }
                    onRowsChanged: {
                        shown.clear();
                        grow.restart();
                    }
                    Component.onCompleted: grow.restart()
                    Timer {
                        id: grow

                        interval: 16
                        repeat: true
                        onTriggered: {
                            const end = Math.min(group.rows.length, shown.count + 8);
                            for (let i = shown.count; i < end; i++)
                                shown.append({ at: i });
                            if (shown.count >= group.rows.length)
                                stop();
                        }
                    }

                    Flickable {
                        id: scroller

                        anchors.top: groupRule.bottom
                        anchors.topMargin: 4
                        anchors.bottom: parent.bottom
                        width: parent.width
                        contentHeight: rowColumn.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        Column {
                            id: rowColumn

                            width: scroller.width

                            Repeater {
                                model: shown

                                Item {
                                    id: row

                                    required property int at
                                    readonly property var modelData: group.rows[at] ?? ({ id: "", keys: "", label: "", defaults: "", ours: false, fixed: false, changed: false })
                                    readonly property bool capturing: overlay.capturing === modelData.id
                                    readonly property bool asking: overlay.pending?.id === modelData.id
                                    // Only the rows in view draw (they keep their size).
                                    readonly property bool inView: y + height > scroller.contentY - 60 && y < scroller.contentY + scroller.height + 60

                                    width: rowColumn.width
                                    height: 26

                                    Item {
                                        anchors.fill: parent
                                        visible: row.inView

                                        Rectangle {
                                            anchors.fill: parent
                                            color: row.capturing || row.asking ? Theme.alpha(Tokens.color.accent, 0.10)
                                                : (hover.hovered && row.modelData.ours ? Theme.cell : "transparent")
                                            Behavior on color {
                                                ColorAnimation {
                                                    duration: Tokens.motion.feedback
                                                    easing.type: Easing.BezierSpline
                                                    easing.bezierCurve: Tokens.motion.easeIn
                                                }
                                            }
                                        }

                                        Text {
                                            anchors.left: parent.left
                                            anchors.leftMargin: 4
                                            anchors.right: caps.left
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            elide: Text.ElideRight
                                            text: row.modelData.label
                                            textFormat: Text.PlainText
                                            color: row.modelData.ours ? Tokens.color.text : Tokens.color.dim
                                            font.family: Tokens.font.data
                                            font.pixelSize: 11
                                            renderType: Text.NativeRendering
                                        }

                                        Row {
                                            id: caps

                                            anchors.right: parent.right
                                            anchors.rightMargin: 4
                                            anchors.verticalCenter: parent.verticalCenter
                                            spacing: 4

                                            Text {
                                                visible: row.capturing
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "PRESS KEYS"
                                                color: Tokens.color.accent
                                                font.family: Tokens.font.data
                                                font.pixelSize: 9
                                                font.letterSpacing: 9 * 0.12
                                                renderType: Text.NativeRendering
                                            }
                                            Text {
                                                visible: !row.capturing && !row.asking && row.modelData.changed
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "RESET"
                                                color: Tokens.color.accent
                                                font.family: Tokens.font.data
                                                font.pixelSize: 9
                                                font.letterSpacing: 9 * 0.12
                                                font.underline: true
                                                renderType: Text.NativeRendering

                                                HoverHandler {
                                                    cursorShape: Qt.PointingHandCursor
                                                }
                                                TapHandler {
                                                    onTapped: Keybinds.reset(row.modelData.id)
                                                }
                                            }
                                            Text {
                                                visible: !row.capturing && row.modelData.keys === ""
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: "NO KEY"
                                                color: Tokens.color.mute
                                                font.family: Tokens.font.data
                                                font.pixelSize: 9
                                                renderType: Text.NativeRendering
                                            }
                                            // Keycaps: 18 px, hairline, a dark fill, 9 px bright --
                                            // accent when changed, alert for keys already in use.
                                            Repeater {
                                                model: row.capturing ? [] : Keybinds.capsOf(row.asking ? overlay.pending.keys : row.modelData.keys)

                                                Rectangle {
                                                    required property string modelData
                                                    readonly property color tone: row.asking ? Tokens.color.alert : row.modelData.changed ? Tokens.color.accent : Tokens.color.bright

                                                    anchors.verticalCenter: parent.verticalCenter
                                                    width: Math.max(18, capText.implicitWidth + 10)
                                                    height: 18
                                                    color: Theme.alpha(Tokens.color.ground, 0.7)
                                                    border.width: 1
                                                    border.color: row.asking ? Tokens.color.alert : row.modelData.changed ? Tokens.color.accent : Tokens.color.hair

                                                    Text {
                                                        id: capText

                                                        anchors.centerIn: parent
                                                        text: parent.modelData
                                                        color: parent.tone
                                                        font.family: Tokens.font.data
                                                        font.pixelSize: 9
                                                        font.weight: Tokens.font.dataWeight
                                                        renderType: Text.NativeRendering
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    HoverHandler {
                                        id: hover
                                        cursorShape: row.modelData.ours ? Qt.PointingHandCursor : Qt.ArrowCursor
                                    }
                                    TapHandler {
                                        enabled: row.modelData.ours && !row.capturing && !row.asking
                                        onTapped: overlay.startCapture(row.modelData.id)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // --- Bottom right: OPEN KEYBINDS FILE, with the bottom-left cut -----------
        Text {
            anchors.right: openFile.left
            anchors.rightMargin: 14
            anchors.verticalCenter: openFile.verticalCenter
            text: "~/.config/wrayth/keybinds.lua · UPDATES NEVER CHANGE IT"
            color: Tokens.color.dim
            font.family: Tokens.font.data
            font.pixelSize: 9
            font.letterSpacing: 9 * 0.1
            renderType: Text.NativeRendering
        }
        ActionButton {
            id: openFile

            x: overlay.originX + overlay.span - width
            y: overlay.height - 86
            width: 220
            text: "OPEN KEYBINDS FILE"
            cutBottomLeft: 8
            onClicked: Keybinds.openFile()
        }

        OverlayKeys {
            id: keys

            anchors.fill: parent
            active: overlay.shown
            onEscaped: {
                if (overlay.pending)
                    overlay.pending = null;
                else
                    ShellState.keybindsOpen = false;
            }

            Keys.onPressed: event => {
                if (overlay.capturing === "")
                    return;
                event.accepted = true;
                if (event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R) {
                    overlay.superAlone = true;
                    return;
                }
                overlay.superAlone = false;
                if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_AltGr].indexOf(event.key) >= 0)
                    return;
                if (event.key === Qt.Key_Delete && event.modifiers === Qt.NoModifier) {
                    overlay.chose(overlay.capturing, "");
                    return;
                }
                const name = overlay.keyName(event.key, event.text);
                if (!name)
                    return;
                overlay.chose(overlay.capturing, overlay.modsOf(event.modifiers).concat([name]).join(" + "));
            }
            // Super on its own, pressed and released: the tap the launcher uses.
            Keys.onReleased: event => {
                if (overlay.capturing === "" || !overlay.superAlone)
                    return;
                if (event.key === Qt.Key_Meta || event.key === Qt.Key_Super_L) {
                    event.accepted = true;
                    overlay.chose(overlay.capturing, "SUPER + SUPER_L");
                }
            }
        }
    }
}
