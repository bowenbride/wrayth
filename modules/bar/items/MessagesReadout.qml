import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// The notification centre's indicator: our speech bubble, and an accent square
// on its corner when anything is unread -- a message waiting in the chat app,
// or a notification not yet seen in COMMS. Always there (it is the way into
// COMMS), and clicking it opens the COMMS dropdown.
Item {
    id: root

    readonly property bool unread: Messages.unread || Notifications.unseen > 0

    implicitWidth: glyph.implicitWidth + 6
    implicitHeight: Appearance.metrics.idleButtonHeight

    MessageGlyph {
        id: glyph

        anchors.centerIn: parent
        color: root.unread ? Tokens.color.bright : Tokens.color.dim

        Behavior on color {
            ColorAnimation {
                duration: Tokens.motion.feedback
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeIn
            }
        }
    }

    // 6 x 6, three px above the bubble's top edge and three past its right --
    // so it sits on the cut corner rather than inside the bubble -- with a
    // 1.5 px ring in the bar's own background so the two shapes separate.
    Rectangle {
        id: ring

        anchors.horizontalCenter: glyph.right
        anchors.verticalCenter: glyph.top
        anchors.horizontalCenterOffset: 3
        anchors.verticalCenterOffset: -3
        visible: root.unread
        width: 9
        height: 9
        color: Tokens.color.barBg

        Rectangle {
            anchors.centerIn: parent
            width: 6
            height: 6
            color: Tokens.color.accent
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    readonly property string dropdownName: "comms"
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    Component.onCompleted: ShellState.registerReadout(root)
    Component.onDestruction: ShellState.unregisterReadout(root)

    TapHandler {
        onTapped: ShellState.toggleDropdown(root)
    }
}
