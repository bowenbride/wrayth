import QtQuick
import qs.config

// `CARD`: the tag that marks the one wallpaper a profile shows on the picker.
//
// It replaces a star. Nothing about `★` says "this is the image the picker
// shows for this profile", so the legend had to say it in words that appeared
// nowhere on the control; the tag is the word, in the profile's own accent so
// it reads as that profile claiming the image.
//
// Two looks, and the difference has to be visible without reading:
//   chosen   -- solid: the profile's accent, its own ground as ink.
//   possible -- outlined: a faint frame in the same accent on an opaque dark
//               backing, shown only under the pointer or under the keyboard.
Item {
    id: root

    // The row's profile, not the shell's.
    property color tone: Theme.accent
    property color ink: Theme.ground
    property bool chosen: false
    property bool hovered: false

    implicitWidth: label.implicitWidth + 10
    implicitHeight: 14

    Rectangle {
        anchors.fill: parent
        // Opaque either way: this sits on a photograph, and a wash over an
        // image cannot be read at any size.
        color: root.chosen ? root.tone : Qt.rgba(0, 0, 0, root.hovered ? 0.88 : 0.74)
        border.width: root.chosen ? 0 : Appearance.metrics.hairline
        border.color: Theme.alpha(root.tone, root.hovered ? 0.95 : 0.6)

        Behavior on color {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }
    }

    NrLabel {
        id: label

        anchors.centerIn: parent
        // A tracked label carries its letter-spacing *after* its last glyph
        // too, so the ink sits half a space left of the box it is centred in.
        // This is the ink's own centre.
        centred: true
        pixelSize: 10
        color: root.chosen ? root.ink : root.tone
        text: "CARD"
    }
}
