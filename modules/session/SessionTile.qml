import QtQuick
import qs.components
import qs.config
import qs.services

// One 150x150 action. Selected wears the accent; armed fills with it and counts
// down, so a second press is the only thing that runs reboot or power off.
ChamferPanel {
    id: root

    required property var tile
    required property bool selected

    readonly property bool armed: Session.armed === tile.id
    // While one tile is armed every other tile stands back, so the choice in
    // front of the user is the confirmation and nothing else.
    readonly property bool otherArmed: Session.armed !== "" && Session.armed !== tile.id

    readonly property bool working: Session.running === tile.id
    readonly property string verb: ({
        lock: "LOCKING",
        logout: "LOGGING OUT",
        sleep: "SLEEPING",
        reboot: "REBOOTING",
        poweroff: "POWERING OFF"
    })[tile.id] ?? "WORKING"

    signal activated

    implicitWidth: 150
    implicitHeight: 150

    chamfer: Appearance.chamfer.panel
    fillColor: {
        if (armed)
            return Theme.alpha(Theme.accent, 0.2);
        if (selected)
            return Theme.alpha(Theme.accent, 0.08);
        return Theme.panel;
    }
    borderColor: selected || armed ? Theme.accent : Theme.hair

    // The dim of every other tile while one is armed. A whole-tile opacity,
    // animated on the shared scale, so the layout never moves.
    opacity: otherArmed ? 0.35 : 1

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.duration.state
            easing.type: Easing.OutCubic
        }
    }

    Behavior on fillColor {
        ColorAnimation {
            duration: Appearance.duration.state
            easing.type: Easing.OutCubic
        }
    }

    // Key badge, top-left.
    Rectangle {
        id: badge

        x: 12
        y: 12
        width: 20
        height: 20
        color: root.selected || root.armed ? Theme.accent : "transparent"
        border.width: Appearance.metrics.hairline
        border.color: root.selected || root.armed ? Theme.accent : Theme.hair

        Text {
            anchors.centerIn: parent
            text: root.tile.key
            color: root.selected || root.armed ? Theme.ground : Theme.dim
            font.family: Appearance.font.data
            font.pixelSize: 11
            font.weight: Appearance.font.weightBold
            renderType: Text.NativeRendering
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 6

        Text {
            renderType: Text.NativeRendering
            anchors.horizontalCenter: parent.horizontalCenter

            text: root.working ? root.verb : (root.armed ? "CONFIRM" : root.tile.label)
            color: root.selected || root.armed ? Theme.bright : Theme.text
            font.family: Appearance.font.display
            font.pixelSize: 17
            font.weight: Appearance.font.weightBold

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.duration.state
                    easing.type: Easing.OutCubic
                }
            }
        }

        // The katakana normally; when armed, the action and the key that runs
        // it -- "LOG OUT, ENTER" -- in the accent, so the confirmation names
        // itself. Both fit the tile, so it never changes size.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter

            text: root.armed ? `${root.tile.label}, ENTER` : root.tile.katakana
            color: root.armed ? Theme.accent : Theme.signal
            font.family: root.armed ? Appearance.font.data : Appearance.font.accent
            font.pixelSize: root.armed ? Appearance.size.label : Appearance.size.katakana
            font.weight: root.armed ? Appearance.font.weightSemi : Appearance.font.weightMedium
            font.letterSpacing: root.armed ? Appearance.tracking(Appearance.size.label) : 0
            font.capitalization: root.armed ? Font.AllUppercase : Font.MixedCase
            renderType: Text.NativeRendering

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.duration.state
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    // The three seconds the armed tile has to be confirmed in.
    Rectangle {
        id: countdown

        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        anchors.left: parent.left
        anchors.leftMargin: 1
        height: 2
        color: Theme.accent
        visible: root.armed

        width: root.armed ? root.width - 2 : 0

        NumberAnimation on width {
            running: root.armed
            from: root.width - 2
            to: 0
            duration: Session.confirmMs
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    Feedback {
        id: feedback

        anchors.fill: parent
        working: root.working
        flashOpacity: 0.22
    }

    WorkSegments {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        running: root.working
    }

    TapHandler {
        enabled: !root.working

        onPressedChanged: if (pressed) feedback.flash()
        onTapped: defer.restart()
    }

    Timer {
        id: defer

        interval: 16
        onTriggered: root.activated()
    }
}
