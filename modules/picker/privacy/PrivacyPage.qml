import QtQuick
import qs.components
import qs.config
import qs.modules.picker
import qs.services

// PRIVACY: what the clipboard history keeps, and when it lets go. Reached from
// the profile picker, like EFFECTS. Applied the moment a chip is pressed.
Item {
    id: root

    signal finished

    // Nothing here opens a question of its own.
    function back(): bool {
        return false;
    }

    readonly property int originX: 250
    readonly property int endX: 1710
    readonly property int span: endX - originX

    readonly property rect contentRect: Qt.rect(originX - 38, 90, span + 76, 700)

    readonly property var historyLabels: ({ memory: "MEMORY ONLY", disk: "SAVE TO DISK", off: "OFF" })
    readonly property var lockLabels: ({ keep: "KEEP HISTORY", clear: "CLEAR HISTORY" })

    BackButton {
        x: root.originX
        y: 96
        onActivated: root.finished()
    }

    Item {
        id: header

        x: root.originX
        y: 151
        width: root.span
        height: 46

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            GlitchText {
                id: privacyTitle

                anchors.verticalCenter: parent.verticalCenter
                text: "PRIVACY"
                pixelSize: 26
            }
            KanaTag {
                anchors.verticalCenter: parent.verticalCenter
                text: "秘匿"
                title: privacyTitle
            }
        }

        NrLabel {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.accent
            text: "APPLIED AT ONCE"
        }
    }

    NrLabel {
        x: root.originX
        y: 223
        color: Theme.dim
        text: "WHAT THE CLIPBOARD HISTORY KEEPS, AND WHEN IT LETS GO"
    }

    EffectsChips {
        x: root.originX
        y: 272
        label: "HISTORY"
        options: ["MEMORY ONLY", "SAVE TO DISK", "OFF"]
        current: root.historyLabels[Clipboard.history]
        onChosen: option => Clipboard.setHistory(Object.keys(root.historyLabels).find(k => root.historyLabels[k] === option))
    }

    Text {
        x: root.originX
        y: 316
        width: 720
        wrapMode: Text.Wrap
        text: {
            if (Clipboard.history === "memory")
                return "Kept in the shell's memory only. Nothing is written to disk, and it is gone when you log out.";
            if (Clipboard.history === "disk")
                return "Also saved to ~/.local/state/wrayth/clipboard.json, readable by your account only, so it survives logging out. Switching away from this deletes the file.";
            return "Nothing is watched and nothing is kept. Super + Shift + V shows an empty list.";
        }
        color: Theme.text
        font.family: Appearance.font.data
        font.pixelSize: 12
        renderType: Text.NativeRendering
    }

    EffectsChips {
        x: root.originX
        y: 392
        label: "ON LOCK"
        options: ["KEEP HISTORY", "CLEAR HISTORY"]
        current: root.lockLabels[Clipboard.onLock]
        onChosen: option => Clipboard.setOnLock(option === "CLEAR HISTORY" ? "clear" : "keep")
    }

    Text {
        x: root.originX
        y: 436
        width: 720
        wrapMode: Text.Wrap
        text: Clipboard.onLock === "clear" ? "Locking the screen empties the history (and the saved file)." : "The history is kept while the screen is locked."
        color: Theme.text
        font.family: Appearance.font.data
        font.pixelSize: 12
        renderType: Text.NativeRendering
    }

    Rectangle {
        x: root.originX
        y: 492
        width: 720
        height: Appearance.metrics.hairline
        color: Theme.hair
    }

    // Fixed: not a setting.
    Row {
        x: root.originX
        y: 512
        spacing: 10

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 6
            height: 6
            color: Theme.signal
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 700
            wrapMode: Text.Wrap
            text: "Anything a password manager marks as sensitive is never recorded, in any mode. Notifications in COMMS are kept until logout and never saved."
            color: Theme.bright
            font.family: Appearance.font.data
            font.pixelSize: 12
            font.weight: Appearance.font.weightSemi
            renderType: Text.NativeRendering
        }
    }
}
