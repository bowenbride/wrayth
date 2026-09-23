import QtQuick
import qs.components
import qs.config

// One vertical bar per CPU thread. A thread at or above 70% goes accent with a
// glow; the rest are signal.
Item {
    id: root

    property var values: []
    property int count: Machine.threadCount
    property real hotThreshold: 0.7
    // Twelve 900 ms animations, retriggered by /proc/stat once a second --
    // which is continuously, deck open or closed. The host says when they
    // are worth running.
    property bool animate: true

    implicitHeight: 50

    Row {
        anchors.fill: parent
        spacing: Math.max(2, (root.width - root.count * 6) / Math.max(1, root.count - 1))

        Repeater {
            model: root.count

            Item {
                required property int index

                readonly property real level: Math.max(0, Math.min(100, root.values[index] ?? 0)) / 100
                readonly property bool hot: level >= root.hotThreshold

                width: 6
                height: root.height

                // The unlit column behind the reading.
                Rectangle {
                    anchors.fill: parent
                    color: Theme.track
                }

                Rectangle {
                    id: fill

                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(1, parent.height * parent.level)
                    color: parent.hot ? Theme.accent : Theme.signal

                    Behavior on height {
                        enabled: root.animate

                        NumberAnimation {
                            duration: Appearance.duration.meter
                            easing.type: Easing.OutCubic
                        }
                    }
                }

            }
        }
    }
}
