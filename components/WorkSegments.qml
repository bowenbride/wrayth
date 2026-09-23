import QtQuick
import qs.config

// The four-segment block that sits beside a working label. Segments fill in
// turn and then start over, so it reads as work continuing rather than as
// progress towards a known end -- none of these actions can say how far along
// they are.
Row {
    id: root

    property bool running: false
    property color litColor: Theme.accent
    property int step: 0

    readonly property int segmentWidth: 5
    readonly property int segmentHeight: 8

    spacing: 3
    opacity: running ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: Appearance.duration.state
            easing.type: Easing.OutCubic
        }
    }

    onRunningChanged: if (running) step = 0

    Repeater {
        model: 4

        Rectangle {
            required property int index

            width: root.segmentWidth
            height: root.segmentHeight
            color: index <= root.step ? root.litColor : Theme.alpha(root.litColor, 0.22)

            Behavior on color {
                ColorAnimation {
                    duration: 90
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Timer {
        interval: 150
        running: root.running
        repeat: true
        onTriggered: root.step = (root.step + 1) % 4
    }
}
