import QtQuick
import Quickshell
import qs.components
import qs.components.ui
import qs.config
import qs.services

// AUDIO (DESIGN.md): `volume_up` (16 px, `dim`), the output's code as a bar
// Value in `signal` (SPKR, HEAD, HDMI, DP, USB, or a Bluetooth model code of
// at most five characters), and the MIC Tag while the microphone is muted.
// Width = icon + the widest code among the outputs there are + the tag's
// slot; nothing else is reserved. Clicking opens the AUDIO dropdown.
Item {
    id: root

    // DESIGN.md: the width fits exactly what is showing -- the icon, the
    // current code, and the MIC tag only while it is shown. Nothing is
    // reserved; a device switch or a mute resizes the readout, eased on the
    // movement timing, and the readouts to its left shift with it.
    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight
    width: implicitWidth
    clip: true

    Behavior on implicitWidth {
        NumberAnimation {
            duration: Tokens.motion.movement
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.motion.easeIn
        }
    }

    Row {
        id: content

        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.space.s6

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "volume_up"
            size: Tokens.icon.bar
            color: Tokens.color.dim
        }

        Value {
            anchors.verticalCenter: parent.verticalCenter
            bar: true
            live: true
            text: Audio.barCode
        }

        // The MIC tag, in the row only while the mic is muted.
        Tag {
            anchors.verticalCenter: parent.verticalCenter
            visible: Audio.barMicMuted
            text: "MIC"
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    readonly property string dropdownName: "audio"
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    Component.onCompleted: ShellState.registerReadout(root)
    Component.onDestruction: ShellState.unregisterReadout(root)

    TapHandler {
        onTapped: ShellState.toggleDropdown(root)
    }
}
