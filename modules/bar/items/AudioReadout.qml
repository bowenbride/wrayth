import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// AUDIO: a speaker and the current output's short name -- `SPEAKERS`, or a
// headset's own name -- and a MIC tag while the microphone is muted. Styled
// like the Bluetooth readout. **Fixed width**: the name sits in a fixed slot
// and the MIC tag's room is always reserved, fading in and out in it, so
// neither a new device nor muting the microphone moves anything on the bar.
// Clicking it opens the AUDIO dropdown.
Row {
    id: root

    spacing: 7

    // volume-high, or volume-off while the output is muted: the glyph stands
    // for the word, in the label grey, as the Bluetooth rune does.
    // A drawn 14 x 13 speaker with one wave, dim.
    SpeakerGlyph {
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.dim
    }

    // The output's short name: 10 px in the data colour, in a fixed slot.
    Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Appearance.slot.audioName
        elide: Text.ElideRight
        text: Audio.sink ? Demo.device(Audio.deviceName, 1) : "NONE"
        textFormat: Text.PlainText
        color: Audio.sink && !Audio.muted ? Theme.signal : Theme.dim
        font.family: Appearance.font.data
        font.pixelSize: 10
        font.weight: Appearance.font.weightSemi
        font.letterSpacing: 10 * 0.1
        renderType: Text.NativeRendering

        Behavior on color {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }
    }

    // A 1 px accent frame around `MIC`: small, and unmistakable. Opacity, not
    // visibility, so its width stays reserved.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: micLabel.implicitWidth + 8
        height: micLabel.implicitHeight + 4
        color: "transparent"
        border.width: Appearance.metrics.hairline
        border.color: Theme.accent
        opacity: Audio.micMuted ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.duration.state
                easing.type: Audio.micMuted ? Easing.OutCubic : Easing.InCubic
            }
        }

        // MIC: 8 px, 0.1em, accent, in a 1 px accent frame.
        Text {
            id: micLabel

            anchors.centerIn: parent
            text: "MIC"
            color: Theme.accent
            font.family: Appearance.font.data
            font.pixelSize: 8
            font.weight: Appearance.font.weightSemi
            font.letterSpacing: 8 * 0.1
            renderType: Text.NativeRendering
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    // Registered with ShellState so `dropdown open audio` can hang the panel
    // where a click would have, on this readout's own screen.
    readonly property string dropdownName: "audio"
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    Component.onCompleted: ShellState.registerReadout(root)
    Component.onDestruction: ShellState.unregisterReadout(root)

    TapHandler {
        onTapped: ShellState.toggleDropdown(root)
    }
}
