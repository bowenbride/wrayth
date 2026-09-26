import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// ADMIN ACCESS: the polkit prompt, matching the lockscreen. What is being
// asked in a plain sentence, then exactly what: the program (when polkit says),
// the action id and the account; a slot-style password field; CANCEL and
// AUTHENTICATE.
//
// **Trust over looks.** It is on the Overlay layer, mapped last, over every
// other surface; every screen is dimmed under it, so nothing on any screen
// can stand in for it or sit convincingly beside it; and the one screen that
// draws the prompt takes the keyboard outright, so no app can read or take the
// keys typed into it. Nothing here authenticates -- polkit's own helper does;
// this passes the answer on and forgets it.
Variants {
    model: ShellState.screens

    PanelWindow {
        id: surface

        required property ShellScreen modelData
        readonly property bool shown: Polkit.active
        readonly property bool primary: shown && Polkit.screen === modelData?.name
        readonly property var flow: Polkit.flow

        screen: modelData
        color: "transparent"
        visible: shown

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wrayth-polkit"
        WlrLayershell.keyboardFocus: primary ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        // The whole screen, dimmed; and every click on it goes nowhere.
        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.6
        }
        MouseArea {
            anchors.fill: parent
        }

        // Cleared whenever a request starts, ends, or is answered.
        onShownChanged: {
            input.text = "";
            if (primary)
                Qt.callLater(() => input.forceActiveFocus());
        }
        onPrimaryChanged: if (primary) Qt.callLater(() => input.forceActiveFocus())

        property bool verifying: false
        Connections {
            target: surface.flow
            ignoreUnknownSignals: true
            function onIsResponseRequiredChanged(): void {
                surface.verifying = false;
                if (surface.flow?.isResponseRequired) {
                    input.text = "";
                    input.forceActiveFocus();
                }
            }
            function onFailedChanged(): void {
                surface.verifying = false;
            }
        }

        function submit(): void {
            if (!flow || !flow.isResponseRequired || verifying)
                return;
            verifying = true;
            const answer = input.text;
            input.text = "";
            flow.submit(answer);
        }
        function cancel(): void {
            input.text = "";
            flow?.cancelAuthenticationRequest();
        }

        ChamferPanel {
            id: panel

            visible: surface.primary
            anchors.centerIn: parent
            width: 560
            height: column.implicitHeight + 36
            chamfer: Appearance.chamfer.panel
            fillColor: Theme.panel2
            borderColor: surface.flow?.failed ? Theme.accent : Theme.hair

            Column {
                id: column

                anchors.top: parent.top
                anchors.topMargin: 18
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.leftMargin: 22
                anchors.rightMargin: 22
                spacing: 14

                Item {
                    width: parent.width
                    height: 22

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        NrLabel {
                            id: adminTitle

                            anchors.verticalCenter: parent.verticalCenter
                            pixelSize: Appearance.size.label + 2
                            color: Theme.bright
                            text: "ADMIN ACCESS"
                        }
                        KanaTag {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "権限"
                            title: adminTitle
                        }
                    }
                }

                // The request, as polkit words it.
                Text {
                    width: parent.width
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: surface.flow?.message ?? ""
                    color: Theme.bright
                    font.family: Appearance.font.data
                    font.pixelSize: 13
                    renderType: Text.NativeRendering
                }

                // Exactly what: program, action, account.
                Column {
                    width: parent.width
                    spacing: 5

                    Repeater {
                        model: [
                            { label: "PROGRAM", value: Polkit.programOf(surface.flow?.message ?? "") || "NOT GIVEN BY THE REQUEST" },
                            { label: "ACTION", value: surface.flow?.actionId ?? "" },
                            { label: "USER", value: Polkit.identityName(surface.flow?.selectedIdentity) || "UNKNOWN" }
                        ]

                        Item {
                            required property var modelData

                            width: parent.width
                            height: 16

                            NrLabel {
                                id: detailLabel

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 84
                                color: Theme.dim
                                text: modelData.label
                            }
                            Text {
                                anchors.left: detailLabel.right
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideMiddle
                                textFormat: Text.PlainText
                                text: modelData.value
                                color: Theme.text
                                font.family: Appearance.font.data
                                font.pixelSize: Appearance.size.body
                                font.weight: Appearance.font.weightSemi
                                renderType: Text.NativeRendering
                            }
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: Appearance.metrics.hairline
                    color: Theme.hair
                }

                NrLabel {
                    color: Theme.dim
                    text: (surface.flow?.inputPrompt || "PASSWORD").replace(/:\s*$/, "").toUpperCase()
                }

                // The answer: slots for a secret (no caret, no frame -- the
                // boxes filling in are the only progress), plain text for the
                // rare prompt that is not one.
                Item {
                    width: parent.width
                    height: 34

                    PassphraseSlots {
                        anchors.left: parent.left
                        visible: !(surface.flow?.responseVisible ?? false)
                        slots: 16
                        slotWidth: 26
                        slotHeight: 34
                        filled: Math.min(16, input.text.length)
                    }
                    Text {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: surface.flow?.responseVisible ?? false
                        text: input.text
                        color: Theme.bright
                        font.family: Appearance.font.data
                        font.pixelSize: 15
                        renderType: Text.NativeRendering
                    }
                }

                NrLabel {
                    color: surface.flow?.failed || surface.flow?.supplementaryIsError ? Theme.accent : Theme.dim
                    text: {
                        if (surface.verifying)
                            return "VERIFYING";
                        if (surface.flow?.supplementaryMessage)
                            return surface.flow.supplementaryMessage.toUpperCase();
                        if (surface.flow?.failed)
                            return `ACCESS DENIED${Appearance.separator}TRY AGAIN`;
                        return "ENTER YOUR PASSWORD TO ALLOW THIS";
                    }
                }

                Row {
                    width: parent.width
                    spacing: 10

                    // Along the panel's bottom edge: the left one takes the
                    // bottom-left cut.
                    ActionButton {
                        width: (parent.width - 10) / 2
                        text: "CANCEL"
                        cutBottomLeft: 8
                        onClicked: surface.cancel()
                    }
                    ActionButton {
                        width: (parent.width - 10) / 2
                        text: surface.verifying ? "VERIFYING" : "AUTHENTICATE"
                        alsoText: ["VERIFYING", "AUTHENTICATE"]
                        accented: true
                        usable: !surface.verifying && input.text.length > 0
                        onClicked: surface.submit()
                    }
                }
            }

            // The real input, out of sight; the slots only draw it.
            TextInput {
                id: input

                width: 1
                height: 1
                opacity: 0
                focus: surface.primary
                echoMode: TextInput.Password
                maximumLength: 256

                Keys.onReturnPressed: surface.submit()
                Keys.onEnterPressed: surface.submit()
                Keys.onEscapePressed: surface.cancel()
            }
        }
    }
}
