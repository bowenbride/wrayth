import QtQuick
import qs.components
import qs.config
import qs.services

// The ident editor: a 2x2 grid of character slots -- code on top, suffix
// beneath -- and an APPLY button. No title; the block above it is the label.
//
// **Nothing here touches the bar until APPLY.** The block keeps showing the
// saved code and suffix the whole time the editor is open, so a half-typed
// value never appears up there and cancelling leaves nothing to undo.
//
// The chamfers inside echo the panel's own: it is cut top-right and bottom-left
// like every bar dropdown, so the top-right slot takes a top-right cut and
// APPLY a bottom-left one. Everything else stays square, and the frames are
// ChamferPanels -- a 1 px outer shape around an inner fill -- so the diagonals
// carry their borders.
ChamferPanel {
    // **Not `root`.** `ChamferPanel` names its own object `root`, and inside a
    // nested one that shadows a `root` from this file -- which had APPLY
    // reading its enabled state off the wrong object.
    id: editor

    readonly property real padding: 14
    readonly property real slotSize: 56
    readonly property real slotGap: 8
    readonly property real innerChamfer: 12

    // One property per slot, in reading order: code left, code right, suffix
    // left, suffix right. Separate properties rather than two strings with
    // spaces standing in for empties, which was fragile.
    property var chars: ["", "", "", ""]
    property int selected: 0

    readonly property string draftCode: chars[0] + chars[1]
    readonly property string draftSuffix: chars[2] + chars[3]
    readonly property bool complete: chars.every(c => c !== "")

    // Resolved here rather than inline on the nested ChamferPanel. A ternary
    // written straight onto a nested component's colour property was not
    // re-evaluating when `complete` changed -- the fill and the label followed
    // it, the border did not -- and an explicit property makes the dependency
    // unambiguous.
    readonly property color applyBorder: complete ? Tokens.color.accent : Theme.alpha(Tokens.color.hair, 0.55)
    readonly property color applyFill: complete ? Tokens.color.accentTint : "transparent"

    chamfer: Tokens.chamfer.dropdown
    fillColor: Tokens.color.panel2

    implicitHeight: body.y + body.implicitHeight + padding

    Component.onCompleted: {
        chars = [Runner.code.charAt(0), Runner.code.charAt(1), Runner.suffix.charAt(0), Runner.suffix.charAt(1)];
        selected = 0;
        input.forceActiveFocus();
    }


    function setChar(index: int, ch: string): void {
        const next = chars.slice();
        next[index] = ch;
        chars = next;
    }

    function accept(ch: string): void {
        const upper = ch.toUpperCase();
        if (!/^[A-Z0-9]$/.test(upper)) {
            // Felt, not swallowed -- the lockscreen's jolt already means
            // "that was not accepted" everywhere else in the shell.
            jolt.restart();
            return;
        }
        setChar(selected, upper);
        if (selected < 3)
            selected = selected + 1;
    }

    function backspace(): void {
        if (chars[selected] !== "") {
            setChar(selected, "");
        } else if (selected > 0) {
            selected = selected - 1;
            setChar(selected, "");
        }
    }

    function apply(): void {
        if (!complete)
            return;
        Runner.saveIdent(draftCode, draftSuffix);
        ShellState.closeDropdown("APPLY in the ID editor");
    }

    // The keys come from a real TextInput parked out of sight: an item inside a
    // focus scope does not take active focus just by asking, and
    // `forceActiveFocus` walks up every scope between.
    TextInput {
        id: input

        width: 0
        height: 0
        opacity: 0
        focus: true

        onTextChanged: {
            if (text.length > 0) {
                editor.accept(text.charAt(text.length - 1));
                text = "";
            }
        }
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Backspace) {
                editor.backspace();
                event.accepted = true;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                editor.apply();
                event.accepted = true;
            }
            // Escape carries up to the dropdown, which closes and reverts.
        }
    }

    SequentialAnimation {
        id: jolt

        NumberAnimation {
            target: body
            property: "shove"
            to: 1
            duration: 60
        }
        PauseAnimation {
            duration: 200
        }
        NumberAnimation {
            target: body
            property: "shove"
            to: 0
            duration: 60
        }
    }

    Column {
        id: body

        property real shove: 0
        readonly property real gridWidth: editor.slotSize * 2 + editor.slotGap

        y: editor.padding
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: editor.slotGap

        transform: [
            Matrix4x4 {
                property real skew: body.shove * -4
                matrix: Qt.matrix4x4(1, Math.tan(skew * Math.PI / 180), 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
            },
            Translate {
                x: body.shove * 6
            }
        ]

        Grid {
            columns: 2
            rowSpacing: editor.slotGap
            columnSpacing: editor.slotGap

            Repeater {
                model: 4

                ChamferPanel {
                    id: slot

                    required property int index

                    readonly property string glyph: editor.chars[index] ?? ""
                    readonly property bool filled: glyph !== ""
                    readonly property bool active: editor.selected === index

                    width: editor.slotSize
                    height: editor.slotSize

                    // Only the top-right slot is cut, parallel to the panel's
                    // own top-right chamfer.
                    chamfer: 0
                    chamferTopRight: index === 1 ? editor.innerChamfer : 0
                    chamferBottomLeft: 0
                    fillColor: slot.active ? Tokens.color.accentTint : "transparent"
                    borderColor: slot.active ? Tokens.color.accent : Tokens.color.hair

                    Text {
                        anchors.centerIn: parent
                        text: slot.glyph
                        color: slot.active ? Tokens.color.accent : (slot.filled ? Tokens.color.text : Tokens.color.mute)
                        font.family: Tokens.font.display
                        font.pixelSize: 24
                        font.weight: Tokens.font.displayWeight
                        renderType: Text.NativeRendering
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: editor.selected = slot.index
                    }
                }
            }
        }

        // Spans the grid, and takes the panel's bottom-left cut.
        ChamferPanel {
            width: body.gridWidth
            height: 32

            chamfer: 0
            chamferTopRight: 0
            chamferBottomLeft: editor.innerChamfer
            fillColor: editor.applyFill
            borderColor: editor.applyBorder

            NrLabel {
                anchors.centerIn: parent
                centred: true
                color: editor.complete ? Tokens.color.accent : Tokens.color.mute
                text: "APPLY"
            }

            Feedback {
                id: feedback

                anchors.fill: parent
                flashOpacity: 0.22
            }

            MouseArea {
                anchors.fill: parent
                enabled: editor.complete
                cursorShape: editor.complete ? Qt.PointingHandCursor : Qt.ArrowCursor

                onPressed: feedback.flash()
                onClicked: defer.restart()
            }

            Timer {
                id: defer

                interval: 16
                onTriggered: editor.apply()
            }
        }
    }
}
