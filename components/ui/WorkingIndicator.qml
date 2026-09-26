import QtQuick
import qs.config

// WorkingIndicator (DESIGN.md): a fill-bar that fills inside the activated
// control's own reserved width while its action runs. Never dots, never a
// spinner. Lay it along the control's bottom edge; `running` drives it.
Item {
    id: root

    property bool running: false
    // 0..1 when the action reports progress; negative for "until done".
    property real progress: -1

    implicitHeight: 2
    visible: running

    Rectangle {
        height: parent.height
        color: Tokens.color.accent
        width: root.progress >= 0 ? parent.width * root.progress : parent.width * sweep.fraction

        QtObject {
            id: sweep
            property real fraction: 0
        }
        NumberAnimation {
            target: sweep
            property: "fraction"
            from: 0
            to: 1
            duration: 1200
            loops: Animation.Infinite
            running: root.running && root.progress < 0 && root.visible
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.motion.easeIn
        }
    }
}
