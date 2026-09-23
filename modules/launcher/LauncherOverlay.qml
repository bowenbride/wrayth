import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
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

        readonly property bool shown: ShellState.launcherOpen

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
            height: header.height + search.height + list.height + footer.height + 2

            chamfer: Appearance.chamfer.panel
            fillColor: Theme.panel2

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

                GlitchFx {
                    group: "overlay"
                    id: title

                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    fills: true
                    textual: true
                    width: execTitle.implicitWidth
                    height: execTitle.implicitHeight
                    scrambleItems: [execTitle]

                    GlitchText {
                        id: execTitle

                        anchors.fill: parent
                        text: "EXEC"
                        pixelSize: 20
                    }
                }

                Text {
                    anchors.left: title.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter

                    text: "実行"
                    color: Theme.signal
                    font.family: Appearance.font.accent
                    font.pixelSize: Appearance.size.katakana
                    font.weight: Appearance.font.weightMedium
                    renderType: Text.NativeRendering
                }

                NrLabel {
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${Launcher.count} MATCHES`
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
                    height: Appearance.metrics.hairline
                    color: Theme.hair
                }

                Text {
                    renderType: Text.NativeRendering
                    id: prompt

                    anchors.left: parent.left
                    anchors.leftMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    text: ">"
                    color: Theme.accent
                    font.family: Appearance.font.data
                    font.pixelSize: Appearance.size.body
                    font.weight: Appearance.font.weightBold
                }

                TextInput {
                    id: input

                    anchors.left: prompt.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter

                    color: Theme.bright
                    selectionColor: Theme.alpha(Theme.accent, 0.35)
                    selectedTextColor: Theme.bright
                    font.family: Appearance.font.data
                    font.pixelSize: Appearance.size.body
                    renderType: Text.NativeRendering

                    cursorDelegate: Rectangle {
                        width: 2
                        color: Theme.accent
                    }

                    onTextChanged: Launcher.query = text
                    Keys.onUpPressed: Launcher.move(-1)
                    Keys.onDownPressed: Launcher.move(1)
                    Keys.onReturnPressed: Launcher.activate()
                    Keys.onEnterPressed: Launcher.activate()
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
            Column {
                id: list

                anchors.top: search.bottom
                anchors.left: parent.left
                anchors.right: parent.right

                Repeater {
                    model: Launcher.results

                    ResultRow {
                        // `index` is a required property on ResultRow itself,
                        // which the Repeater fills directly -- redeclaring it
                        // here made the binding refer to itself.
                        required property var modelData

                        width: list.width
                        result: modelData
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

                anchors.top: list.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                height: 34

                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    height: Appearance.metrics.hairline
                    color: Theme.hair
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
                        color: Theme.mute
                    }

                    NrLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.mute
                        text: "SELECT"
                    }

                    Keycap {
                        anchors.verticalCenter: parent.verticalCenter
                        key: "ENTER"
                        color: Theme.mute
                    }

                    NrLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.mute
                        text: "EXEC"
                    }

                    Keycap {
                        anchors.verticalCenter: parent.verticalCenter
                        key: "ESC"
                        color: Theme.mute
                    }

                    NrLabel {
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.mute
                        text: "ABORT"
                    }
                }
            }
        }
    }
}
