import QtQuick
import qs.config
import qs.utils

// A volume you can set: the shared 20-segment meter (5% a segment, lit by
// `round(percentage / 5)` -- SegmentMeter's one rule), with its figure beside
// it in a slot that reserves "MUTED", so the row never moves.
//
// Press or drag to set it (it snaps to the 5% steps the keys use), scroll to
// step it. `changed` reports the new value; whoever owns the node applies it,
// and `value` comes back from PipeWire -- the meter always shows the truth,
// never a guess.
Item {
    id: root

    property real value: 0
    property bool muted: false
    property color litColor: Theme.signal
    property bool usable: true
    property real segmentHeight: 8

    signal changed(real value)

    implicitHeight: Math.max(segmentHeight, figure.implicitHeight)
    implicitWidth: 240

    NrLabel {
        id: reserve

        visible: false
        text: "MUTED"
    }

    // The meter and what takes the pointer, side by side in one box: a
    // MouseArea inside the meter's Row would be laid out as a segment.
    Item {
        anchors.left: parent.left
        anchors.right: figure.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: root.segmentHeight

        SegmentMeter {
            id: meter

            anchors.fill: parent
            segments: 20
            spacing: 2
            segmentWidth: (width - (segments - 1) * spacing) / segments
            segmentHeight: root.segmentHeight
            value: root.value
            // The data colour lit, the alert colour lit while muted.
            litColor: root.muted ? Theme.alert : root.litColor
            unlitColor: Theme.track
            animate: false
            opacity: root.usable ? 1 : 0.4
        }

        MouseArea {
            anchors.fill: parent
            anchors.topMargin: -6
            anchors.bottomMargin: -6
            enabled: root.usable
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function at(x: real): real {
                return Math.round(Math.max(0, Math.min(1, x / width)) * 20) / 20;
            }

            onPressed: mouse => root.changed(at(mouse.x))
            onPositionChanged: mouse => {
                if (pressed)
                    root.changed(at(mouse.x));
            }
            onWheel: wheel => root.changed(Math.max(0, Math.min(1, Math.round(root.value * 20 + (wheel.angleDelta.y > 0 ? 1 : -1)) / 20)))
        }
    }

    // The percentage: 10 px, right-aligned in a 36 px slot. The segments light
    // by the shared rule, round(percentage / 5) (SegmentMeter).
    Text {
        id: figure

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        horizontalAlignment: Text.AlignRight
        color: root.muted ? Theme.alert : Theme.text
        text: `${Math.round(root.value * 100)}%`
        font.family: Appearance.font.data
        font.pixelSize: 10
        renderType: Text.NativeRendering
    }
}
