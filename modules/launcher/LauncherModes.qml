import QtQuick
import Quickshell
import Quickshell.Io
import qs.components
import qs.config
import qs.services
import "calc.js" as Calc

// The launcher's modes, chosen by the first character of the query:
//   =  CALCULATE  one result; ENTER copies it. A plain sum answers without it.
//   :  EMOJI      a 10-column grid searched by name; ENTER copies.
//   >  COMMAND    RUN IN KITTY or RUN IN BACKGROUND; recent commands first.
// With none of them the launcher is the app list as before (`mode` is "").
Item {
    id: root

    property string query: ""

    readonly property var calc: {
        if (query.startsWith("="))
            return Calc.evaluate(query.slice(1), false);
        if (/^[\s\d.(+-]/.test(query))
            return Calc.evaluate(query, true);
        return null;
    }
    readonly property string mode: query.startsWith("=") ? "calc" : query.startsWith(":") ? "emoji" : query.startsWith(">") ? "command" : (calc ? "calc" : "")
    readonly property string modeName: ({ calc: "CALCULATE", emoji: "EMOJI", command: "COMMAND" })[mode] ?? ""
    readonly property bool active: mode !== ""

    implicitHeight: mode === "calc" ? calcView.height : mode === "emoji" ? emojiView.height : mode === "command" ? commandView.height : 0

    signal done

    // --- Keys, from the search field -------------------------------------------
    property int selected: 0
    onQueryChanged: selected = 0
    onModeChanged: selected = 0

    function move(by: int): void {
        const n = mode === "emoji" ? emojiResults.length : mode === "command" ? commandRows.length : 1;
        if (n > 0)
            selected = Math.max(0, Math.min(n - 1, selected + by));
    }
    function activate(): void {
        if (mode === "calc") {
            if (calc)
                copy(calc.result.replace(/ [a-z]+$/, ""));
        } else if (mode === "emoji") {
            const e = emojiResults[selected];
            if (e)
                copy(e[0]);
        } else if (mode === "command") {
            const r = commandRows[selected];
            if (r && r.usable)
                run(r.command, r.kind === "background");
        }
    }
    function copy(text: string): void {
        Quickshell.execDetached(["wl-copy", "--", text]);
        done();
    }

    // --- = CALCULATE -------------------------------------------------------------
    Item {
        id: calcView

        visible: root.mode === "calc"
        width: parent.width
        height: 104

        Column {
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.calc ? root.calc.expression : (root.query.slice(1).trim() || "TYPE A SUM")
                textFormat: Text.PlainText
                color: Theme.dim
                font.family: Appearance.font.data
                font.pixelSize: 11
                renderType: Text.NativeRendering
            }
            Text {
                width: parent.width
                elide: Text.ElideRight
                text: root.calc ? root.calc.result : "—"
                textFormat: Text.PlainText
                color: root.calc ? Theme.bright : Theme.mute
                font.family: Appearance.font.display
                font.pixelSize: 30
                font.weight: Appearance.font.weightBold
                renderType: Text.NativeRendering
            }
            Text {
                text: "ENTER COPIES THE RESULT"
                color: Theme.dim
                font.family: Appearance.font.data
                font.pixelSize: 9
                font.letterSpacing: 9 * 0.12
                renderType: Text.NativeRendering
            }
        }
    }

    // --- : EMOJI -----------------------------------------------------------------
    // The names are read once, the first time the mode is used.
    property var emoji: []
    FileView {
        id: emojiFile

        path: root.mode === "emoji" || root.emoji.length > 0 ? Quickshell.shellPath("assets/emoji.json") : ""
        onLoaded: {
            try {
                root.emoji = JSON.parse(text());
            } catch (e) {}
        }
    }
    readonly property var emojiResults: {
        if (mode !== "emoji")
            return [];
        const words = query.slice(1).trim().toLowerCase().split(/\s+/).filter(w => w !== "");
        const out = [];
        for (const e of emoji) {
            // Each word must start a word of the name: "cat" is a cat, not
            // multiplication.
            const parts = e[1].split(/[\s-]+/);
            if (words.every(w => parts.some(p => p.startsWith(w))))
                out.push(e);
            if (out.length >= 50)
                break;
        }
        return out;
    }

    Item {
        id: emojiView

        visible: root.mode === "emoji"
        width: parent.width
        height: Math.max(1, Math.ceil(root.emojiResults.length / 10)) * 44 + 24

        Grid {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: 12
            columns: 10
            spacing: 0

            Repeater {
                model: root.emojiResults

                Rectangle {
                    id: cell

                    required property var modelData
                    required property int index
                    readonly property bool sel: index === root.selected

                    width: 44
                    height: 44
                    color: sel ? Theme.alpha(Theme.accent, 0.12) : (cellHover.hovered ? Theme.cell : "transparent")
                    border.width: sel ? 1 : 0
                    border.color: Theme.accent

                    Text {
                        anchors.centerIn: parent
                        text: cell.modelData[0]
                        font.pixelSize: 22
                    }
                    HoverHandler {
                        id: cellHover
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: {
                            root.selected = cell.index;
                            root.activate();
                        }
                    }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: root.emojiResults.length === 0
            text: root.emoji.length === 0 ? "LOADING" : "NO EMOJI BY THAT NAME"
            color: Theme.dim
            font.family: Appearance.font.data
            font.pixelSize: 9
            font.letterSpacing: 9 * 0.12
            renderType: Text.NativeRendering
        }
    }

    // --- > COMMAND ---------------------------------------------------------------
    // Recent commands follow the clipboard's privacy setting: nothing kept
    // when it is off, the runtime directory (gone at logout) when it is
    // memory only, ~/.local/state/wrayth when it is kept on disk.
    readonly property string historyFile: Clipboard.history === "disk" ? `${Quickshell.env("HOME")}/.local/state/wrayth/commands.json` : Clipboard.history === "memory" ? `${Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"}/wrayth/commands.json` : ""
    property var recent: []
    FileView {
        id: historyView

        path: root.mode === "command" ? root.historyFile : ""
        printErrors: false
        onLoaded: {
            try {
                root.recent = JSON.parse(text()).filter(c => typeof c === "string").slice(0, 20);
            } catch (e) {}
        }
    }
    FileView {
        id: historyWriter
        path: root.historyFile
        printErrors: false
    }

    // Never as root: sudo, doas, pkexec, su and run0 are refused.
    function asRoot(cmd: string): bool {
        return /^(sudo|doas|pkexec|su|run0)(\s|$)/.test(cmd.trim());
    }

    readonly property string typed: mode === "command" ? query.slice(1).trim() : ""
    readonly property var commandRows: {
        if (mode !== "command")
            return [];
        const rows = [];
        const matches = recent.filter(c => c !== typed && (typed === "" || c.startsWith(typed))).slice(0, 5);
        for (const c of matches)
            rows.push({ kind: "recent", command: c, label: c, tag: "RECENT", usable: !asRoot(c) });
        if (typed !== "") {
            const ok = !asRoot(typed);
            rows.push({ kind: "kitty", command: typed, label: ok ? "RUN IN KITTY" : "NEVER RUN AS ROOT", tag: typed, usable: ok });
            if (ok)
                rows.push({ kind: "background", command: typed, label: "RUN IN BACKGROUND", tag: typed, usable: true });
        }
        return rows;
    }
    // A typed command puts its RUN rows first; recent ones lead only while
    // nothing is typed.
    onTypedChanged: selected = typed !== "" ? commandRows.findIndex(r => r.kind === "kitty") : 0

    function run(cmd: string, background: bool): void {
        if (cmd === "" || asRoot(cmd))
            return;
        Deck.leave();
        if (background)
            Quickshell.execDetached({ command: ["sh", "-c", cmd], workingDirectory: Quickshell.env("HOME") });
        else
            Quickshell.execDetached({ command: ["kitty", "--hold", "sh", "-c", cmd], workingDirectory: Quickshell.env("HOME") });
        if (historyFile !== "") {
            recent = [cmd].concat(recent.filter(c => c !== cmd)).slice(0, 20);
            historyWriter.setText(JSON.stringify(recent));
        }
        done();
    }

    Column {
        id: commandView

        visible: root.mode === "command"
        width: parent.width
        topPadding: 6
        bottomPadding: 6

        Text {
            visible: root.commandRows.length === 0
            x: 16
            height: 32
            verticalAlignment: Text.AlignVCenter
            text: "TYPE A COMMAND"
            color: Theme.dim
            font.family: Appearance.font.data
            font.pixelSize: 9
            font.letterSpacing: 9 * 0.12
            renderType: Text.NativeRendering
        }

        Repeater {
            model: root.commandRows

            Rectangle {
                id: crow

                required property var modelData
                required property int index
                readonly property bool sel: index === root.selected

                width: commandView.width
                height: 32
                color: sel ? Theme.alpha(Theme.ground, 0.55) : "transparent"

                Rectangle {
                    width: 2
                    height: parent.height
                    color: Theme.accent
                    visible: crow.sel
                }
                Text {
                    id: crowLabel

                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    width: crow.modelData.kind === "recent" ? parent.width - 110 : implicitWidth
                    elide: Text.ElideRight
                    text: crow.modelData.label
                    textFormat: Text.PlainText
                    color: !crow.modelData.usable ? Theme.alert : (crow.sel ? Theme.bright : Theme.text)
                    font.family: Appearance.font.data
                    font.pixelSize: crow.modelData.kind === "recent" ? 12 : 11
                    font.weight: crow.modelData.kind === "recent" ? Appearance.font.weightRegular : Appearance.font.weightSemi
                    font.letterSpacing: crow.modelData.kind === "recent" ? 0 : 11 * 0.1
                    renderType: Text.NativeRendering
                }
                Text {
                    anchors.left: crowLabel.right
                    anchors.leftMargin: 12
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideMiddle
                    text: crow.modelData.tag
                    textFormat: Text.PlainText
                    color: Theme.dim
                    font.family: Appearance.font.data
                    font.pixelSize: 9
                    font.letterSpacing: crow.modelData.kind === "recent" ? 9 * 0.12 : 0
                    renderType: Text.NativeRendering
                }
                HoverHandler {
                    cursorShape: crow.modelData.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
                TapHandler {
                    onTapped: {
                        root.selected = crow.index;
                        root.activate();
                    }
                }
            }
        }
    }
}
