import QtQuick
import qs.components
import qs.config
import qs.services

// AUTH // PASSPHRASE: the 560x196 panel under the clock.
ChamferPanel {
    id: root

    readonly property real padding: 18

    implicitWidth: 560
    implicitHeight: 196

    chamfer: Appearance.chamfer.panel
    fillColor: Theme.panel2
    borderColor: Lock.state === "denied" || Lock.lockedOut ? Theme.accent : Theme.hair

    // The wrong-passphrase glitch: a shove and a shear for 420 ms.
    property real shove: 0

    transform: [
        Matrix4x4 {
            property real skew: root.shove * -4
            matrix: Qt.matrix4x4(1, Math.tan(skew * Math.PI / 180), 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
        },
        Translate {
            x: root.shove * 6
        }
    ]

    SequentialAnimation {
        id: glitch

        NumberAnimation {
            target: root
            property: "shove"
            to: 1
            duration: 60
        }
        PauseAnimation {
            duration: 300
        }
        NumberAnimation {
            target: root
            property: "shove"
            to: 0
            duration: 60
        }
    }

    Connections {
        target: Lock

        function onStateChanged(): void {
            if (Lock.state !== "denied")
                return;
            glitch.restart();
            Glitch.fireHard("lock");
        }
    }

    // --- Header ------------------------------------------------------------
    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.padding
        height: 18

        // **The strongest glitch in the shell lands here.** A failed unlock
        // is the one moment the shell is being told no, and it gets all three
        // effects at the top of the duration band -- on top of the shove and
        // shear the panel already does.
        GlitchFx {
            group: "lock"
            id: authFx

            key: "lock"
            textual: true
            fills: true
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: authRow.implicitWidth
            height: authRow.implicitHeight
            scrambleItems: [authTitle]

        Row {
            id: authRow

            anchors.fill: parent
            spacing: 8

            NrLabel {
                id: authTitle

                anchors.verticalCenter: parent.verticalCenter
                color: Theme.bright
                text: `AUTH${Appearance.separator}PASSPHRASE`
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "認証"
                color: Theme.signal
                font.family: Appearance.font.accent
                font.pixelSize: Appearance.size.katakana
                font.weight: Appearance.font.weightMedium
                renderType: Text.NativeRendering
            }
        }
        }

        NrLabel {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: Lock.attempts > 0 ? Theme.accent : Theme.mute
            text: `FAILED ${Lock.attempts}`
        }
    }

    // --- Slots -------------------------------------------------------------
    PassphraseSlots {
        id: slots

        anchors.top: header.bottom
        anchors.topMargin: 26
        anchors.horizontalCenter: parent.horizontalCenter

        slots: Lock.maxLength
        slotWidth: 26
        slotHeight: 34
        filled: Math.min(Lock.maxLength, Lock.buffer.length)
    }

    // The same working state every other action in the shell shows, while PAM
    // has the passphrase. The panel is not an `ActionButton`, but the parts are
    // shared: the segment block and the sweep along the bottom edge.
    WorkSegments {
        anchors.top: slots.bottom
        anchors.topMargin: 6
        anchors.horizontalCenter: parent.horizontalCenter
        running: Lock.busy
    }

    Feedback {
        anchors.fill: parent
        working: Lock.busy
        succeeded: Lock.granted
        flashOpacity: 0.18
    }

    // --- Message -----------------------------------------------------------
    Text {
        id: message

        renderType: Text.NativeRendering
        anchors.top: slots.bottom
        anchors.topMargin: 22
        anchors.horizontalCenter: parent.horizontalCenter

        // **A faillock lockout says so, and for how long.** The time comes from
        // the user's own tally file when it is readable (exact, counting down),
        // else from PAM's "(N minutes left to unlock)" line (a whole-minute
        // ceiling), else there is none and the message says only to wait.
        // Centred in the panel, so a longer line moves nothing else; tabular
        // figures, so the countdown does not shuffle as its digits change.
        text: {
            if (Lock.granted)
                return `ACCESS GRANTED${Appearance.separator}RESUMING SESSION`;
            if (Lock.busy)
                return "VERIFYING";
            if (Lock.keyboardLost)
                return `KEYBOARD LOST${Appearance.separator}RECOVER FROM A CONSOLE`;
            if (Lock.lockedOut) {
                if (Lock.lockoutSource === "tally" && Lock.lockoutLeft > 0)
                    return `ACCOUNT LOCKED${Appearance.separator}RETRY IN ${Math.floor(Lock.lockoutLeft / 60)}:${String(Lock.lockoutLeft % 60).padStart(2, "0")}`;
                if (Lock.lockoutSource === "pam" && Lock.lockoutLeft > 0)
                    return `ACCOUNT LOCKED${Appearance.separator}ABOUT ${Math.ceil(Lock.lockoutLeft / 60)} MIN LEFT`;
                return `ACCOUNT LOCKED${Appearance.separator}WAIT, THEN RETRY`;
            }
            if (Lock.state === "denied")
                return `ACCESS DENIED${Appearance.separator}ATTEMPT ${Lock.attempts} LOGGED`;
            if (Lock.notice === "timeout")
                return `NO ANSWER FROM PAM${Appearance.separator}TRY AGAIN`;
            return "ENTER PASSPHRASE TO RESUME SESSION";
        }
        color: {
            if (Lock.granted)
                return Theme.signal;
            if (Lock.keyboardLost || Lock.lockedOut || Lock.state === "denied" || Lock.notice)
                return Theme.accent;
            return Theme.dim;
        }
        font.features: Appearance.tabularFigures
        font.family: Appearance.font.data
        font.pixelSize: Appearance.size.label
        font.weight: Appearance.font.weightSemi
        font.letterSpacing: Appearance.tracking(Appearance.size.label)
        font.capitalization: Font.AllUppercase
    }

    // **How to recover, when the lock cannot get the keyboard back itself.**
    // Its own line under the message, in the panel's reserved space so nothing
    // moves, and in its real case -- the message above is set in capitals, and
    // a path typed back in capitals would not run.
    Text {
        id: recoverHint

        renderType: Text.NativeRendering
        anchors.top: message.bottom
        anchors.topMargin: 8
        anchors.horizontalCenter: parent.horizontalCenter
        visible: Lock.keyboardLost
        text: "Ctrl+Alt+F3, log in, then run  ~/.local/bin/wrayth-recover"
        textFormat: Text.PlainText
        color: Theme.text
        font.family: Appearance.font.data
        font.pixelSize: Appearance.size.label
        font.weight: Appearance.font.weightSemi
    }
}
