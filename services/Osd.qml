pragma Singleton

import QtQuick
import Quickshell
import qs.services

// Which of the two popups is up, and for how long. They show on a change and
// never at start-up, so the first reading of each source only arms them.
Singleton {
    id: root

    // "", "volume" or "brightness".
    property string showing: ""
    // What was last shown, kept so the panel does not change identity while it
    // is fading out.
    property string lastShown: "volume"
    property bool armed: false

    function flash(which: string): void {
        if (!armed)
            return;
        showing = which;
        lastShown = which;
        hide.restart();
    }

    // Long enough for the sources to report their starting values, which would
    // otherwise pop both panels up the moment the shell loads.
    Timer {
        interval: 1200
        running: true
        onTriggered: root.armed = true
    }

    Timer {
        id: hide

        interval: 1800
        onTriggered: root.showing = ""
    }

    Connections {
        target: Audio

        function onVolumeChanged(): void {
            root.flash("volume");
        }

        function onMutedChanged(): void {
            root.flash("volume");
        }
    }

    Connections {
        target: Brightness

        function onValueChanged(): void {
            root.flash("brightness");
        }
    }
}
