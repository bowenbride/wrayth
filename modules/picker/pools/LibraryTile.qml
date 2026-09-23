import QtQuick
import qs.components
import qs.config
import qs.services

// One file in the wallpapers folder. `DEFAULT` marks a preset's generated
// wallpaper and `GENERATED` a custom profile's; anything else the user has put
// in the folder carries no tag, because it is simply theirs.
Item {
    id: root

    required property var entry
    // The keyboard's position in the pools screen. The pointer is not the only
    // way to reach a tile's controls.
    property bool focused: false

    readonly property bool revealed: hover.hovered || root.focused

    signal deleteRequested
    // Screen coordinates, so the screen can carry the ghost and work out which
    // row it was let go over.
    signal dragStarted(var payload, real x, real y)
    signal dragMoved(real x, real y)
    signal dragEnded

    implicitWidth: 190
    implicitHeight: 110

    Rectangle {
        anchors.fill: parent
        color: Theme.deep
        border.width: Appearance.metrics.hairline
        border.color: root.revealed ? Theme.accent : Theme.hair

        Behavior on border.color {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }
    }

    Image {
        anchors.fill: parent
        anchors.margins: 1
        source: Wallpapers.imageOf(root.entry.file)
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(380, 220)
        asynchronous: true
        cache: true
        opacity: root.revealed ? 1 : 0.86
    }

    NrLabel {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: 5
        visible: root.entry.tag.length > 0
        pixelSize: 10
        color: Theme.ground
        text: root.entry.tag

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            z: -1
            color: root.entry.tag === "GENERATED" ? Theme.signal : Theme.accent
        }
    }

    // Deleting a file from the user's library is the one destructive thing on
    // this screen, so it asks -- see the confirmation the screen puts up.
    //
    // **A word, in `alert`, under the pointer.** It used to be a drawn `×` in
    // a box, which is what a pool chip's remove control was too -- so the one
    // control in the shell that destroys a file looked exactly like the one
    // that quietly takes a wallpaper out of a profile. They do not do the same
    // thing and they no longer look as though they might, which is also why
    // this no longer has to be permanent: it was made always-visible to tell
    // the two apart, and that put a red button on every thumbnail in the
    // library for a control nobody uses most days.
    //
    // **Its box does not move when it appears** -- only the opacity changes,
    // so the tile's layout is the same whether the pointer is on it or not.
    Rectangle {
        id: del

        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 5
        width: delLabel.implicitWidth + 14
        height: 20
        visible: opacity > 0
        opacity: root.revealed ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.revealed ? Appearance.duration.state : Appearance.duration.exit
                easing.type: root.revealed ? Easing.OutCubic : Easing.InCubic
            }
        }

        // Opaque: this sits on a photograph, and the one control on this
        // screen that destroys a file has to be the one you can read.
        color: Qt.rgba(0, 0, 0, closeHover.hovered ? 0.95 : 0.82)
        border.width: Appearance.metrics.hairline
        border.color: closeHover.hovered ? Theme.alert : Theme.alpha(Theme.alert, 0.7)

        Behavior on color {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }

        NrLabel {
            id: delLabel

            anchors.centerIn: parent
            centred: true
            pixelSize: 10
            color: Theme.alert
            text: "DELETE"
        }

        HoverHandler {
            id: closeHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.deleteRequested()
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 1
        height: 22
        color: Qt.rgba(0, 0, 0, 0.82)

        NrLabel {
            anchors.fill: parent
            anchors.leftMargin: 6
            anchors.rightMargin: 6
            pixelSize: 10
            color: Theme.bright
            elide: Text.ElideMiddle
            text: root.entry.name
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    MouseArea {
        id: area

        anchors.fill: parent
        // DELETE and the tile itself both want the pointer; DELETE is a
        // handler on a child, which is above this in the same stack, so it
        // wins where it is and this takes everything else.
        propagateComposedEvents: true

        property bool dragging: false
        property point origin

        onPressed: mouse => {
            origin = Qt.point(mouse.x, mouse.y);
            dragging = false;
        }

        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const moved = Math.abs(mouse.x - origin.x) + Math.abs(mouse.y - origin.y);
            const global = root.mapToItem(null, mouse.x, mouse.y);
            if (!dragging && moved > 6) {
                dragging = true;
                root.dragStarted(root.entry.file, global.x, global.y);
            } else if (dragging) {
                root.dragMoved(global.x, global.y);
            }
        }

        onReleased: {
            if (dragging)
                root.dragEnded();
            dragging = false;
        }

        // A grab can be taken away; the drag still has to end. See PoolChip.
        onCanceled: {
            if (dragging)
                root.dragEnded();
            dragging = false;
        }
    }
}
