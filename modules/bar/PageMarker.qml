import QtQuick
import qs.components
import qs.config
import qs.services

// The workspace page marker: which page of workspaces the indicator beside it
// is showing, and how many there are. It sits where the hazard stripes were,
// with the bar's accent line running underneath it unbroken.
//
// **Changing page never moves anything along the bar** -- the bar's standing
// no-shifting rule. That falls out of `Spaces.pipCount` resting at three pips
// rather than out of a fixed width here: paging leaves the count alone, it only
// moves which pip is lit. The marker is therefore only as wide as the pips it
// is actually showing, so it can sit right against the workspace slots instead
// of holding open room for pages nobody has. It does widen by one pip's pitch
// when a workspace on a third page is created, which is a rare, deliberate act
// rather than a value ticking over.
Item {
    id: root

    // Five normal pages covers workspaces 1 to 25, and one more for the
    // special page. Beyond that the pips stop being countable at a glance
    // anyway, so the marker does not grow.
    readonly property int maxPips: 6
    readonly property int pipSize: 5
    readonly property int pipGap: 3
    readonly property int labelGap: 8

    readonly property int shown: Math.max(1, Math.min(Spaces.pipCount, maxPips))

    implicitWidth: labelSlot.implicitWidth + labelGap + shown * (pipSize + pipGap) - pipGap
    implicitHeight: 11


    // A fixed slot measured from the widest label, so `P1` and `SPC` occupy
    // the same room.
    TextMetrics {
        id: widest

        font: label.font
        text: "SPC"
    }

    Item {
        id: labelSlot

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: widest.advanceWidth
        implicitHeight: label.implicitHeight

        NrLabel {
            id: label

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.dim
            text: Spaces.pageLabel
        }
    }

    Row {
        id: pips

        anchors.left: labelSlot.right
        anchors.leftMargin: root.labelGap
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.pipGap

        Repeater {
            model: root.shown

            Rectangle {
                required property int index

                readonly property bool lit: index === Math.min(Spaces.litPip, root.shown - 1)

                width: root.pipSize
                height: root.pipSize
                color: lit ? Theme.accent : Theme.hair

                Behavior on color {
                    ColorAnimation {
                        duration: Appearance.duration.state
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

}
