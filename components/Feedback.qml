import QtQuick
import qs.config

// The shared interaction feedback every clickable in the shell draws: the press
// flash, the sweep that runs while an action is working, and the success flash.
// It is an overlay rather than a base class so it can go over a bordered button,
// a bare row, a tile or a tickbox without any of them changing shape.
//
// The host keeps ownership of its own border -- they are all drawn differently --
// and binds to `flashing` and the state it already has to brighten it.
Item {
    id: root

    property bool working: false
    property bool succeeded: false
    property bool failed: false

    // The failure jolt, the same shove and shear the lockscreen uses for a
    // wrong passphrase. It cannot be applied from in here -- transforming an
    // overlay would only shake the overlay -- so the host binds its own
    // transform to this and the movement is shared rather than reinvented.
    property real shove: 0
    // Covers the press flash on hosts whose own fill would otherwise hide it.
    property real flashOpacity: 0.35

    readonly property bool flashing: press.running

    // The press flash is deliberately not tied to the action starting. It fires
    // the moment the pointer goes down and is over in 120 ms, so an element
    // always acknowledges the click even when the work behind it takes a second
    // or fails immediately.
    function flash(): void {
        pressFill.opacity = 1;
        press.restart();
    }

    Rectangle {
        id: pressFill

        anchors.fill: parent
        color: Theme.alpha(Theme.accent, root.flashOpacity)
        opacity: 0
    }

    NumberAnimation {
        id: press

        target: pressFill
        property: "opacity"
        from: 1
        to: 0
        duration: Appearance.duration.state
        easing.type: Easing.OutCubic
    }

    Rectangle {
        id: okFill

        anchors.fill: parent
        color: Theme.alpha(Theme.signal, root.flashOpacity)
        opacity: 0
    }

    NumberAnimation {
        id: okFlash

        target: okFill
        property: "opacity"
        from: 1
        to: 0
        // The spec's "about 260 ms", on the scale: 250 is the panel figure and
        // a success flash is the one state feedback that is deliberately
        // longer than 120, because it marks a moment rather than a press.
        duration: Appearance.duration.panel
        easing.type: Easing.OutCubic
    }

    onSucceededChanged: if (succeeded) okFlash.restart()
    onFailedChanged: if (failed) jolt.restart()

    // **The failure jolt is the spec's own figure and is not on the shared
    // scale**: 60 ms in, 300 held, 60 out. It is not a transition between two
    // states, it is a shove -- the shell being told no -- and it is the one
    // piece of motion in the shell that is meant to be uncomfortable.
    SequentialAnimation {
        id: jolt

        NumberAnimation {
            target: root
            property: "shove"
            to: 1
            duration: 60
        }
        PauseAnimation {
            duration: 300
        }
        NumberAnimation {
            target: root
            property: "shove"
            to: 0
            duration: 60
        }
    }

    // The 2 px line travelling along the bottom edge while work is in progress.
    Item {
        id: sweepTrack

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: 2
        clip: true
        visible: root.working

        Rectangle {
            id: sweep

            width: Math.max(24, sweepTrack.width * 0.35)
            height: parent.height
            color: Theme.accent
        }

        NumberAnimation {
            target: sweep
            property: "x"
            from: -sweep.width
            to: sweepTrack.width
            duration: 900
            loops: Animation.Infinite
            running: root.working
        }
    }
}
