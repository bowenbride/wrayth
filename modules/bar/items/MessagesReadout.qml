import QtQuick
import Quickshell.Hyprland
import qs.components
import qs.config
import qs.services

// Unread messages: our speech bubble, and an accent square on its corner when
// something is waiting. The whole item goes when the client is not running --
// the ticker absorbs the width, which is the rule the ID block established.
Item {
    id: root

    readonly property bool unread: Messages.unread

    // A `Row` skips an invisible child entirely, its spacing included, so
    // hiding this closes the gap without any width juggling here.
    visible: Messages.running

    implicitWidth: glyph.implicitWidth + 6
    implicitHeight: Appearance.metrics.idleButtonHeight

    MessageGlyph {
        id: glyph

        anchors.centerIn: parent
        color: root.unread ? Theme.bright : Theme.dim

        Behavior on color {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
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
        color: Theme.barBg

        Rectangle {
            anchors.centerIn: parent
            width: 6
            height: 6
            color: Theme.accent
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        // The same thing Super + D does.
        onTapped: Hyprland.dispatch(`hl.dsp.workspace.toggle_special("communication")`)
    }
}
