import QtQuick
import qs.config

// A scrollbar for a Flickable, in the shell's own weight: thin, a `dim` thumb
// on a dark track, accent while the pointer is on it. Qt's own is a rounded
// pill that belongs to a different design system.
Item {
    id: root

    required property Flickable view

    readonly property real span: Math.max(1, view.contentHeight)
    readonly property real fraction: Math.min(1, view.height / span)
    readonly property bool needed: view.contentHeight > view.height + 1

    implicitWidth: 4

    visible: needed

    Rectangle {
        anchors.fill: parent
        color: Theme.alpha(Theme.deep, 0.6)
    }

    Rectangle {
        id: thumb

        width: parent.width
        height: Math.max(24, root.view.height * root.fraction)
        y: root.view.height > 0 ? (root.view.height - height) * Math.max(0, Math.min(1, root.view.contentY / Math.max(1, root.span - root.view.height))) : 0
        color: hover.hovered || drag.drag.active ? Theme.accent : Theme.dim

        Behavior on color {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }
    }

    HoverHandler {
        id: hover
    }

    MouseArea {
        id: drag

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor

        // Dragging the bar scrolls the view rather than moving the thumb: the
        // thumb's position is a reading of `contentY`, not a thing of its own.
        function scrollTo(y: real): void {
            const travel = Math.max(1, height - thumb.height);
            const at = Math.max(0, Math.min(1, (y - thumb.height / 2) / travel));
            root.view.contentY = at * Math.max(0, root.span - root.view.height);
        }

        onPressed: mouse => scrollTo(mouse.y)
        onPositionChanged: mouse => {
            if (pressed)
                scrollTo(mouse.y);
        }
    }
}
