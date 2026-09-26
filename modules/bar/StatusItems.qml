import QtQuick
import qs.components
import qs.config
import qs.services
import qs.modules.bar.items

// The right-hand readouts, separated by hairline dividers.
Row {
    id: root

    spacing: Appearance.metrics.dividerGap

    // Set by the bar when it runs short: see `metrics.tickerMin`.
    property alias btCompact: bt.compact
    // The group's width with the Bluetooth name showing, whichever way it is
    // showing -- what the bar decides by.
    readonly property real fullWidth: implicitWidth - bt.implicitWidth + bt.fullWidth

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
    AudioReadout {
        anchors.verticalCenter: parent.verticalCenter
    }
    Divider {
        anchors.verticalCenter: parent.verticalCenter
    }
    BtReadout {
        id: bt

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
    TrayReadout {
        anchors.verticalCenter: parent.verticalCenter
    }
    Divider {
        anchors.verticalCenter: parent.verticalCenter
    }
    // The notification centre: always there now, so its divider is too.
    MessagesReadout {
        anchors.verticalCenter: parent.verticalCenter
    }
    Divider {
        anchors.verticalCenter: parent.verticalCenter
    }
    // The input mode, only with two or more layouts or an input method.
    InputReadout {
        anchors.verticalCenter: parent.verticalCenter
        visible: InputModes.shown
    }
    Divider {
        anchors.verticalCenter: parent.verticalCenter
        visible: InputModes.shown
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
