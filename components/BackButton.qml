import QtQuick
import qs.config

// `BACK`, top-left of every view that takes the screen.
//
// **Escape is not discoverable, and it was the only way out of five screens.**
// Each of them said `[ESC]` somewhere in a footer, which is a legend rather
// than a control: it tells you the key after you have found the screen, and it
// is nowhere near the corner anybody's pointer goes to first.
//
// It carries the word and the keycap together, so it teaches the key it
// replaces rather than replacing it. **Its top-left corner is cut**, the
// design system's chamfer language turned to point back the way you came, and
// it is styled as a secondary control -- a hairline frame and `dim` text that
// take the accent under the pointer -- so it never competes with the view's
// own primary action.
//
// It never gains a meaning of its own: a host wires it to the same function
// Escape calls, and nothing else.
Item {
    id: root

    signal activated

    // The `[ESC]` keycap is on by default because most hosts wire Escape to the
    // same reverse. A host where Escape does not reach it (the deck's daemon
    // detail, where the terminal owns the keyboard) sets this false rather than
    // advertising a key that does nothing.
    property bool showKey: true

    implicitWidth: content.implicitWidth + 30
    implicitHeight: 30

    readonly property color tone: hover.hovered ? Theme.accent : Theme.dim

    ChamferPanel {
        anchors.fill: parent

        chamfer: 8
        chamferTopLeft: 8
        chamferTopRight: 0
        chamferBottomLeft: 0
        fillColor: hover.hovered ? Theme.alpha(Theme.hair, 0.4) : Theme.alpha(Theme.hair, 0.18)
        borderColor: root.tone
        // A control inside a full-screen view is already inside whatever the
        // view draws; it does not carry its own overlay.
        scanlines: false

        Behavior on fillColor {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }

        Behavior on borderColor {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: 8

        NrLabel {
            anchors.verticalCenter: parent.verticalCenter
            centred: true
            color: root.tone
            text: "BACK"

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.duration.state
                    easing.type: Easing.OutCubic
                }
            }
        }

        Keycap {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showKey
            key: "ESC"
            color: root.tone
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    Feedback {
        id: feedback

        anchors.fill: parent
        flashOpacity: 0.3
    }

    TapHandler {
        onPressedChanged: if (pressed) feedback.flash()
        onTapped: defer.restart()
    }

    // One frame between the flash and the work, so the acknowledgement is
    // painted first.
    Timer {
        id: defer

        interval: 16
        onTriggered: root.activated()
    }
}
