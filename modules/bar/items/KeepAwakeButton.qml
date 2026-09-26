import QtQuick
import qs.components
import qs.components.ui
import qs.config
import qs.services

// IDLE // AUTO or IDLE // HOLD. The inhibitor itself is held by the bar window,
// which is the surface the Wayland protocol needs; this only flips the flag.
Rectangle {
    id: root

    readonly property bool held: Idle.hold

    // IDLE (DESIGN.md): IDLE // AUTO or HOLD in a 1 px `hair` frame -- the one
    // framed readout, because it is a toggle. AUTO and HOLD share one slot.
    implicitWidth: row.implicitWidth + 2 * Tokens.measure.chipPadding
    implicitHeight: Tokens.measure.buttonInline

    color: "transparent"
    border.width: Tokens.measure.hairline
    border.color: Tokens.color.hair

    Row {
        id: row

        anchors.centerIn: parent
        spacing: Tokens.space.s6

        Label {
            anchors.verticalCenter: parent.verticalCenter
            bar: true
            text: "IDLE"
        }
        Label {
            anchors.verticalCenter: parent.verticalCenter
            bar: true
            text: "//"
            color: Tokens.color.hair
        }
        Value {
            id: value

            anchors.verticalCenter: parent.verticalCenter
            bar: true
            width: widest.width
            text: root.held ? "HOLD" : "AUTO"
            color: root.held ? Tokens.color.accent : Tokens.color.text
            Behavior on color {
                ColorAnimation {
                    duration: Tokens.motion.feedback
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.motion.easeIn
                }
            }
            TextMetrics {
                id: widest
                font: value.font
                text: "HOLD"
            }
        }
    }
    Feedback {
        id: feedback

        anchors.fill: parent
        flashOpacity: 0.3
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        // Instant: the inhibitor is held the moment this is clicked, and the
        // button's own ON/OFF state is the confirmation.
        onPressed: feedback.flash()
        onClicked: Idle.toggle()
    }

}
