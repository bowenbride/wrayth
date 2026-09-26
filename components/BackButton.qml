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

    // DESIGN.md, the full-screen BackControl: a secondary button reading BACK
    // with an ESC keycap, 22 px, a 5 px top-left chamfer (corner echo).
    implicitWidth: content.implicitWidth + 2 * Tokens.space.s10
    implicitHeight: Tokens.measure.buttonInline

    readonly property color tone: Tokens.color.text

    ChamferPanel {
        anchors.fill: parent

        chamfer: 0
        chamferTopLeft: Tokens.chamfer.backControl
        chamferTopRight: 0
        chamferBottomRight: 0
        chamferBottomLeft: 0
        fillColor: Tokens.color.panelHex
        borderColor: hover.hovered ? Tokens.color.dim : Tokens.color.hair
        // A control inside a full-screen view is already inside whatever the
        // view draws; it does not carry its own overlay.
        scanlines: false

        Behavior on fillColor {
            ColorAnimation {
                duration: Tokens.motion.feedback
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeIn
            }
        }

        Behavior on borderColor {
            ColorAnimation {
                duration: Tokens.motion.feedback
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeIn
            }
        }
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Tokens.space.s6

        NrLabel {
            anchors.verticalCenter: parent.verticalCenter
            centred: true
            pixelSize: Tokens.type.button.size
            font.letterSpacing: Tokens.type.button.size * Tokens.type.button.tracking
            color: root.tone
            text: "BACK"

            Behavior on color {
                ColorAnimation {
                    duration: Tokens.motion.feedback
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.motion.easeIn
                }
            }
        }

        Keycap {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.showKey
            key: "ESC"
            color: Tokens.color.bright
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
