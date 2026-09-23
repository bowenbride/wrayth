import QtQuick
import qs.components
import qs.config
import qs.modules.bar.items

// The right-hand readouts, separated by hairline dividers.
Row {
    id: root

    spacing: Appearance.metrics.dividerGap

    // The three figures on the left of the group, each its own target and each
    // a number: split and slice, never scramble.
    GlitchFx {
        group: "bar"
        fills: true

        anchors.verticalCenter: parent.verticalCenter
        width: cpu.implicitWidth
        height: cpu.implicitHeight
        numeric: true

        CpuReadout {
            id: cpu

            anchors.fill: parent
        }
    }
    Divider {
        anchors.verticalCenter: parent.verticalCenter
    }
    GlitchFx {
        group: "bar"
        fills: true

        anchors.verticalCenter: parent.verticalCenter
        width: mem.implicitWidth
        height: mem.implicitHeight
        numeric: true

        MemReadout {
            id: mem

            anchors.fill: parent
        }
    }
    Divider {
        anchors.verticalCenter: parent.verticalCenter
    }
    GlitchFx {
        group: "bar"
        fills: true

        anchors.verticalCenter: parent.verticalCenter
        width: net.implicitWidth
        height: net.implicitHeight
        numeric: true

        NetReadout {
            id: net

            anchors.fill: parent
        }
    }
    Divider {
        anchors.verticalCenter: parent.verticalCenter
    }
    BtReadout {
        anchors.verticalCenter: parent.verticalCenter
    }
    Divider {
        anchors.verticalCenter: parent.verticalCenter
    }
    PwrReadout {
        anchors.verticalCenter: parent.verticalCenter
    }
    Divider {
        anchors.verticalCenter: parent.verticalCenter
    }
    KeepAwakeButton {
        anchors.verticalCenter: parent.verticalCenter
    }
    Divider {
        anchors.verticalCenter: parent.verticalCenter
    }
    MessagesReadout {
        id: messages

        anchors.verticalCenter: parent.verticalCenter
    }
    // Fenced on both sides like every other readout; without this the bubble
    // grouped with the time and read as part of the clock. It hides with the
    // indicator it separates -- a `Row` skips an invisible child and its
    // spacing, so when the client is not running both go and the bar never
    // ends up with two dividers side by side. Bound to the indicator's own
    // visibility rather than re-deriving it, so there is one source of truth.
    Divider {
        anchors.verticalCenter: parent.verticalCenter
        visible: messages.visible
    }
    // **The clock is a figure, so it never scrambles.** It may split and slice
    // like anything else, but a time that flickers through junk for 150 ms is
    // a time somebody might read, and the whole point of the rule is that a
    // number on this shell is always the truth.
    GlitchFx {
        group: "bar"
        fills: true

        anchors.verticalCenter: parent.verticalCenter
        width: clock.implicitWidth
        height: clock.implicitHeight
        numeric: true

        BarClock {
            id: clock

            anchors.fill: parent
        }
    }
}
