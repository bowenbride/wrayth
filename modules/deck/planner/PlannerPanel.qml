import QtQuick
import QtQml.Models
import qs.components
import qs.config
import qs.services

// QUEUE // DAILY GIGS: the bottom row's left panel. Gigs are edited in place --
// click a name to rename and retag it, drag the grip to reorder, the minus to
// remove, and + ADD GIG at the foot for a new one -- and every change is
// written straight back to the same hand-editable planner file.
ChamferPanel {
    id: root

    readonly property real padding: 14

    chamfer: Appearance.chamfer.panel
    fillColor: Tokens.color.panel

    // The task index being edited in place, or -1. A separate flag for the
    // new-gig editor at the foot. While either is up, dragging is suspended.
    property int editingIndex: -1
    property bool adding: false
    // Set true only across a live drag, so a rebuild does not clobber the
    // ListView's own reordering mid-gesture.
    property bool dragging: false

    // Tell the deck to take the keyboard while a field is up, so text can be
    // typed; it hands it back the moment the editor closes.
    onEditingIndexChanged: Planner.editing = editingIndex !== -1 || adding
    onAddingChanged: Planner.editing = editingIndex !== -1 || adding

    // The list the ListView draws, mirrored from Planner and rebuilt whenever
    // the gigs change (a tick, an edit, an external file edit, the reset).
    ListModel {
        id: gigModel
    }

    function rebuild(): void {
        if (root.dragging)
            return;
        gigModel.clear();
        for (const entry of Planner.ordered)
            gigModel.append({
                taskIndex: entry.index,
                name: entry.name,
                tag: entry.tag,
                done: entry.done,
                status: entry.status
            });
    }

    function commitOrder(): void {
        const list = [];
        for (let i = 0; i < visualModel.items.count; i++) {
            const item = visualModel.items.get(i).model;
            list.push({
                done: item.done,
                name: item.name,
                tag: item.tag
            });
        }
        root.dragging = false;
        Planner.setOrder(list);
    }

    Connections {
        target: Planner

        function onOrderedChanged(): void {
            root.rebuild();
        }
    }

    Component.onCompleted: root.rebuild()

    DelegateModel {
        id: visualModel

        model: gigModel

        delegate: TaskRow {
            editing: root.editingIndex === model.taskIndex
            anyEditing: root.editingIndex !== -1 || root.adding

            onEditRequested: root.editingIndex = model.taskIndex
            onEditCommitted: (name, tag) => {
                Planner.update(model.taskIndex, name, tag);
                root.editingIndex = -1;
            }
            onEditCancelled: root.editingIndex = -1

            onMoveRequested: (from, to) => {
                root.dragging = true;
                visualModel.items.move(from, to);
            }
            onReordered: root.commitOrder()
        }
    }

    // --- Header --------------------------------------------------------------
    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.padding
        height: 18

        GlitchFx {
            group: "deck"
            key: "panel:planner"
            fills: true
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: plannerHeaderRow.implicitWidth
            height: plannerHeaderRow.implicitHeight

            Row {
                id: plannerHeaderRow

                anchors.fill: parent
                spacing: 8

                NrLabel {
                    id: taggedTitle

                    anchors.verticalCenter: parent.verticalCenter
                    color: Tokens.color.bright
                    text: "DAILY GIGS"
                }

                KanaTag {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "依頼"
                    title: taggedTitle
                }
            }
        }

        NrLabel {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: Planner.done === Planner.total && Planner.total > 0 ? Tokens.color.signal : Tokens.color.dim
            text: `${Planner.done}/${Planner.total} CLEARED`
        }
    }

    // One segment per task, lit as they are cleared.
    SegmentMeter {
        id: progress

        anchors.top: header.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding

        segments: Math.max(1, Planner.total)
        spacing: 3
        segmentWidth: (width - (segments - 1) * spacing) / segments
        segmentHeight: 4
        value: Planner.total > 0 ? Planner.done / Planner.total : 0
        litColor: Tokens.color.signal
    }

    // --- The gigs ------------------------------------------------------------
    ListView {
        id: gigList

        anchors.top: progress.bottom
        anchors.topMargin: 10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: addFoot.top
        anchors.bottomMargin: 6
        anchors.leftMargin: root.padding - 6
        anchors.rightMargin: root.padding - 6

        model: visualModel
        clip: true
        interactive: false
        // The rows slide aside as one is dragged through them.
        moveDisplaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Tokens.motion.movement
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeIn
            }
        }
        displaced: Transition {
            NumberAnimation {
                properties: "x,y"
                duration: Tokens.motion.movement
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeIn
            }
        }
    }

    // An empty planner says how to fill it. Over the empty list, so it moves
    // nothing, and gone the moment a gig exists or one is being added.
    Column {
        anchors.centerIn: gigList
        spacing: 6
        opacity: Planner.total === 0 && !root.adding ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.motion.feedback
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeIn
            }
        }

        NrLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Tokens.color.dim
            text: "NO GIGS QUEUED"
        }

        NrLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            color: Tokens.color.mute
            text: "+ ADD GIG BELOW TO QUEUE YOUR FIRST"
        }
    }

    // --- Add, or the new-gig editor ------------------------------------------
    Item {
        id: addFoot

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.padding
        anchors.leftMargin: root.padding - 6
        anchors.rightMargin: root.padding - 6
        height: 28

        // The new-gig editor when adding, otherwise the add control.
        Loader {
            anchors.fill: parent
            active: root.adding

            sourceComponent: GigEdit {
                focusOnShow: true

                onCommitted: (name, tag) => {
                    Planner.append(name, tag);
                    root.adding = false;
                }
                onCancelled: root.adding = false
            }
        }

        ActionButton {
            anchors.fill: parent
            visible: !root.adding
            text: "+ ADD GIG"
            onClicked: {
                root.editingIndex = -1;
                root.adding = true;
            }
        }
    }
}
