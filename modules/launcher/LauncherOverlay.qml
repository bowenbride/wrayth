import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.components.ui as UI
import qs.config
import qs.services

// EXEC //: centred over the desktop, which the `wrayth-overlay` blur rule
// blurs for us -- a full-screen surface is exactly what that rule wants here,
// unlike the deck, which has a terminal showing through it.
Variants {
    model: ShellState.screens

    PanelWindow {
        id: overlay

        required property ShellScreen modelData

        // One screen only: see `ShellState.overlayScreen`.
        readonly property bool shown: ShellState.launcherOpen && ShellState.overlayScreen === modelData?.name

        screen: modelData
        color: "transparent"
        // Hyprland's `animation = fade` layer rule fades the whole surface,
        // blur included. Fading it again in QML would double it.
        visible: shown

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wrayth-overlay"
        // It is a text field; it needs the keyboard outright.
        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        onShownChanged: if (shown) input.forceActiveFocus()

        // The spec's 45% dim. The blur behind it is Hyprland's.
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.45
        }

        // Anywhere outside the panel closes.
        MouseArea {
            anchors.fill: parent
            onClicked: Launcher.close()
        }

        ChamferPanel {
            id: panel

            anchors.horizontalCenter: parent.horizontalCenter
            y: 190

            width: 680
            height: header.height + search.height + (modes.active ? modes.implicitHeight : list.height) + footer.height + 2

            chamfer: Tokens.chamfer.centred
            fillColor: Tokens.color.panel2

            // Swallows clicks so they do not reach the dismiss layer behind.
            MouseArea {
                anchors.fill: parent
            }

            // --- Header ----------------------------------------------------
            Item {
                id: header

                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                height: 52

                // The centred-panel header: Title + JapaneseLabel, a hint on the right.
                // Split and slice still find it (DESIGN.md); no scramble.
                GlitchFx {
                    group: "overlay"
                    anchors.left: parent.left
                    anchors.leftMargin: Tokens.space.s16
                    anchors.verticalCenter: parent.verticalCenter
                    fills: true
                    width: execTitle.implicitWidth
                    height: execTitle.implicitHeight
                    UI.Title {
                        id: execTitle
                        text: "EXEC"
                        japanese: "実行"
                    }
                }

                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: Tokens.space.s16
                    anchors.verticalCenter: parent.verticalCenter
                    text: modes.active ? "" : `${Launcher.count} MATCHES`
                    color: Tokens.color.dim
                    font.family: Tokens.type.hint.family
                    font.pixelSize: Tokens.type.hint.size
                    font.letterSpacing: Tokens.type.hint.size * Tokens.type.hint.tracking
                    renderType: Text.NativeRendering
                }
            }

            // --- Search ----------------------------------------------------
            Item {
                id: search

                anchors.top: header.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 46

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: Tokens.measure.hairline
                    color: Tokens.color.hair
                }

                Text {
                    renderType: Text.NativeRendering
                    id: prompt

                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: ">"
                    color: Tokens.color.accent
                    font.family: Tokens.font.data
                    font.pixelSize: Appearance.size.body
                    font.weight: Appearance.font.weightBold
                }

                // The current mode's name, at the right of the field.
                Text {
                    id: modeName

                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: modes.modeName
                    color: Tokens.color.signal
                    font.family: Tokens.font.data
                    font.pixelSize: 9
                    font.weight: Tokens.font.dataWeight
                    font.letterSpacing: 9 * 0.14
                    renderType: Text.NativeRendering
                }

                TextInput {
                    id: input

                    anchors.left: prompt.right
                    anchors.leftMargin: 10
                    anchors.right: modeName.left
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter

                    color: Tokens.color.bright
                    selectionColor: Theme.alpha(Tokens.color.accent, 0.35)
                    selectedTextColor: Tokens.color.bright
                    font.family: Tokens.font.data
                    font.pixelSize: Appearance.size.body
                    renderType: Text.NativeRendering

                    cursorDelegate: Rectangle {
                        width: 2
                        color: Tokens.color.accent
                    }

                    onTextChanged: Launcher.query = text
                    Keys.onUpPressed: modes.active ? modes.move(modes.mode === "emoji" ? -10 : -1) : Launcher.move(-1)
                    Keys.onDownPressed: modes.active ? modes.move(modes.mode === "emoji" ? 10 : 1) : Launcher.move(1)
                    Keys.onLeftPressed: event => {
                        if (modes.mode === "emoji")
                            modes.move(-1);
                        else
                            event.accepted = false;
                    }
                    Keys.onRightPressed: event => {
                        if (modes.mode === "emoji")
                            modes.move(1);
                        else
                            event.accepted = false;
                    }
                    Keys.onReturnPressed: modes.active ? modes.activate() : Launcher.activate()
                    Keys.onEnterPressed: modes.active ? modes.activate() : Launcher.activate()
                    Keys.onEscapePressed: Launcher.close()
                }

                // Cleared on every open, so the field never keeps a stale query.
                Connections {
                    target: ShellState

                    function onLauncherOpenChanged(): void {
                        if (ShellState.launcherOpen) {
                            input.text = "";
                            input.forceActiveFocus();
                        }
                    }
                }
            }

            // --- Results ---------------------------------------------------
            LauncherModes {
                id: modes

                anchors.top: search.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                visible: active
                query: input.text
                onDone: Launcher.close()
            }

            Column {
                id: list

                anchors.top: search.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                visible: !modes.active

                // **A fixed set of rows that rebind, not a model of results.**
                // Given the results array as its model, the Repeater destroyed
                // and rebuilt every row on each keystroke and every change to
                // the app list, launcher closed or not.
                Repeater {
                    model: Launcher.maxResults

                    ResultRow {
                        // `index` is a required property on ResultRow itself,
                        // which the Repeater fills directly.
                        width: list.width
                        visible: index < Launcher.results.length
                        result: Launcher.results[index] ?? ({ kind: "app", name: "", tag: "", points: 0, uses: 0 })
                        selected: index === Launcher.selected

                        onActivated: {
                            Launcher.selected = index;
                            Launcher.activate();
                        }
                    }
                }
            }

            // --- Footer ----------------------------------------------------
            Item {
                id: footer

                anchors.top: modes.active ? modes.bottom : list.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 34

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: Tokens.measure.hairline
                    color: Tokens.color.hair
                }

                // Keys in keycaps. The row's own spacing supplies the air the
                // separator's spaces would have given.
                //
                // The hint does not mention the mouse: clicking a row you can
                // already see is the first thing anyone tries, so saying it
                // cost a third of the line to tell people what they were about
                // to do anyway.
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Keycap {
                        anchors.verticalCenter: parent.verticalCenter
                        key: "↑↓"
                        color: Tokens.color.mute
                    }

                    NrLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Tokens.color.mute
                        text: "SELECT"
                    }

                    Keycap {
                        anchors.verticalCenter: parent.verticalCenter
                        key: "ENTER"
                        color: Tokens.color.mute
                    }

                    NrLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Tokens.color.mute
                        text: "EXEC"
                    }

                    Keycap {
                        anchors.verticalCenter: parent.verticalCenter
                        key: "ESC"
                        color: Tokens.color.mute
                    }

                    NrLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Tokens.color.mute
                        text: "ABORT"
                    }
                }

                // The modes, by their prefixes.
                Text {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: "= CALCULATE · : EMOJI · > RUN A COMMAND"
                    color: Tokens.color.dim
                    font.family: Tokens.font.data
                    font.pixelSize: 9
                    font.letterSpacing: 9 * 0.12
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
