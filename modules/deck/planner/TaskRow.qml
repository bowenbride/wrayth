import QtQuick
import qs.components
import qs.config
import qs.services

// One gig, as a reorderable list delegate. Collapsed it is a grip, a tickbox,
// the name, its category and its status, with a quiet minus to remove it.
// Clicking the name turns the row into the inline editor. The grip drags the
// row to reorder it; the others slide out of the way through the ListView's
// own move transitions.
Item {
    id: dg

    required property var model
    required property int index

    // Set by the panel: whether this row is the one being edited, and whether
    // any row is (which suspends dragging).
    property bool editing: false
    property bool anyEditing: false

    signal editRequested
    signal editCommitted(string name, string tag)
    signal editCancelled
    signal moveRequested(int from, int to)
    signal reordered

    width: dg.ListView.view ? dg.ListView.view.width : 0
    height: 28

    readonly property bool isActive: model.status === "ACTIVE"
    readonly property bool isDone: model.status === "DONE"
    property bool held: false

    // --- The inline editor, in place of the row -----------------------------
    Loader {
        anchors.fill: parent
        anchors.leftMargin: 6
        anchors.rightMargin: 6
        active: dg.editing

        sourceComponent: GigEdit {
            initialName: dg.model.name
            initialTag: dg.model.tag
            focusOnShow: true

            onCommitted: (name, tag) => dg.editCommitted(name, tag)
            onCancelled: dg.editCancelled()
        }
    }

    // --- The row itself, which is what gets dragged --------------------------
    Item {
        id: content

        anchors.horizontalCenter: dg.horizontalCenter
        anchors.verticalCenter: dg.verticalCenter
        width: dg.width
        height: dg.height
        visible: !dg.editing
        z: dg.held ? 2 : 1

        Drag.active: dragArea.drag.active
        Drag.source: dg
        Drag.hotSpot.x: width / 2
        Drag.hotSpot.y: height / 2

        // While dragging, the row lifts out of the list flow so it floats over
        // its neighbours instead of being clipped or carried by the positioner.
        states: State {
            when: dg.held

            ParentChange {
                target: content
                parent: dg.ListView.view
            }

            AnchorChanges {
                target: content
                anchors.horizontalCenter: undefined
                anchors.verticalCenter: undefined
            }
        }

        Rectangle {
            anchors.fill: parent
            color: dg.held ? Theme.alpha(Theme.accent, 0.12)
                : (dg.isActive ? Theme.alpha(Theme.accent, 0.06) : "transparent")
        }

        // --- Grip -----------------------------------------------------------
        Item {
            id: grip

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 16

            // Two columns of three dots -- the ordinary drag-handle mark.
            Row {
                anchors.centerIn: parent
                spacing: 3

                Repeater {
                    model: 2

                    Column {
                        spacing: 3

                        Repeater {
                            model: 3

                            Rectangle {
                                width: 2
                                height: 2
                                radius: 0
                                color: dragArea.containsMouse || dg.held ? Theme.text : Theme.mute
                            }
                        }
                    }
                }
            }

            MouseArea {
                id: dragArea

                anchors.fill: parent
                hoverEnabled: true
                enabled: !dg.editing && !dg.anyEditing
                cursorShape: Qt.SizeVerCursor

                drag.target: dg.held ? content : undefined
                drag.axis: Drag.YAxis

                onPressed: dg.held = true
                onReleased: {
                    dg.held = false;
                    dg.reordered();
                }
            }
        }

        Tickbox {
            id: box

            anchors.left: grip.right
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            checked: dg.isDone
            active: dg.isActive

            onToggled: Planner.toggle(dg.model.taskIndex)
        }

        // --- Name (click to edit) -------------------------------------------
        Text {
            id: name

            anchors.left: box.right
            anchors.leftMargin: 10
            anchors.right: tag.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            text: dg.model.name
            textFormat: Text.PlainText
            color: {
                if (dg.isDone)
                    return Theme.mute;
                if (dg.isActive)
                    return Theme.bright;
                if (dg.model.status === "NEXT")
                    return Theme.text;
                return Theme.dim;
            }
            font.family: Appearance.font.data
            font.pixelSize: Appearance.size.body
            font.strikeout: dg.isDone
            elide: Text.ElideRight
            maximumLineCount: 1
            renderType: Text.NativeRendering

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.IBeamCursor
                enabled: !dg.anyEditing
                onClicked: dg.editRequested()
            }
        }

        NrLabel {
            id: tag

            anchors.right: status.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.mute
            text: dg.model.tag
        }

        // status slot sized to the widest word so the tag column stays put.
        Text {
            id: statusSlot

            visible: false
            text: "QUEUED"
            font: status.font
            renderType: Text.NativeRendering
        }

        Text {
            id: status

            anchors.right: minus.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            width: statusSlot.implicitWidth
            horizontalAlignment: Text.AlignRight

            text: dg.model.status
            color: {
                if (dg.isActive)
                    return Theme.accent;
                if (dg.isDone)
                    return Theme.mute;
                if (dg.model.status === "NEXT")
                    return Theme.text;
                return Theme.dim;
            }
            font.family: Appearance.font.data
            font.pixelSize: Appearance.size.label
            font.weight: Appearance.font.weightSemi
            font.letterSpacing: Appearance.tracking(Appearance.size.label)
            font.capitalization: Font.AllUppercase
            renderType: Text.NativeRendering
        }

        // --- The quiet minus ------------------------------------------------
        Item {
            id: minus

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18

            MinusGlyph {
                anchors.centerIn: parent
                color: minusArea.containsMouse ? Theme.alert : Theme.mute
                opacity: rowHover.hovered || minusArea.containsMouse ? 1 : 0.4

                Behavior on opacity {
                    NumberAnimation {
                        duration: Appearance.duration.state
                        easing.type: Easing.OutCubic
                    }
                }
            }

            MouseArea {
                id: minusArea

                anchors.fill: parent
                anchors.margins: -3
                hoverEnabled: true
                enabled: !dg.anyEditing
                cursorShape: Qt.PointingHandCursor
                onClicked: Planner.remove(dg.model.taskIndex)
            }
        }

        HoverHandler {
            id: rowHover
        }
    }

    // --- Reordering ----------------------------------------------------------
    // A row dragged over this one asks the panel to move it, so the ListView's
    // move transition slides the rest of the rows aside.
    DropArea {
        anchors.fill: parent

        onEntered: drag => {
            const from = drag.source.DelegateModel.itemsIndex;
            const to = dg.DelegateModel.itemsIndex;
            if (from !== to)
                dg.moveRequested(from, to);
        }
    }
}
