import QtQuick
import qs.components
import qs.config
import qs.services

// IDLE // AUTO or IDLE // HOLD. The inhibitor itself is held by the bar window,
// which is the surface the Wayland protocol needs; this only flips the flag.
Rectangle {
    id: root

    readonly property bool held: Idle.hold

    implicitWidth: row.implicitWidth + 18
    implicitHeight: Appearance.metrics.idleButtonHeight

    color: held ? Theme.alpha(Theme.accent, 0.12) : "transparent"
    border.width: Appearance.metrics.hairline
    border.color: held ? Theme.accent : Theme.hair

    Behavior on color {
        ColorAnimation {
            duration: Appearance.duration.state
            easing.type: Easing.OutCubic
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: Appearance.duration.state
            easing.type: Easing.OutCubic
        }
    }

    Row {
        id: row

        anchors.centerIn: parent
        spacing: 5

        NrLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: "IDLE"
        }

        NrLabel {
            anchors.verticalCenter: parent.verticalCenter
            text: "//"
            color: Theme.mute
        }

        // Fixed slot so AUTO and HOLD are the same width.
        Item {
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: Appearance.slot.idleValue
            implicitHeight: value.implicitHeight

            Text {
                renderType: Text.NativeRendering
                id: value

                anchors.centerIn: parent

                text: root.held ? "HOLD" : "AUTO"
                color: root.held ? Theme.accent : Theme.text
                font.family: Appearance.font.data
                font.pixelSize: Appearance.size.label
                font.weight: Appearance.font.weightSemi
                font.letterSpacing: Appearance.tracking(Appearance.size.label)
                font.capitalization: Font.AllUppercase
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
