import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.components as C
import qs.components.ui
import qs.config
import qs.services
import qs.utils

Row {
    id: root

    readonly property var battery: UPower.displayDevice
    // UPower reports percentage as 0..1.
    readonly property real charge: (battery?.percentage ?? 0) * 100
    readonly property bool unplugged: UPower.onBattery && (battery?.isPresent ?? false)

    spacing: Tokens.space.s8

    // PWR (DESIGN.md): Label, then Value -- AC, or the battery percentage,
    // in a slot as wide as the widest it can read (100% on a machine with a
    // battery, AC without one).
    Label {
        anchors.verticalCenter: parent.verticalCenter
        bar: true
        text: "PWR"
    }
    // The small meter, as built before the style pass (DESIGN.md).
    C.SegmentMeter {
        anchors.verticalCenter: parent.verticalCenter
        segments: Tokens.measure.barMeterSegments
        segmentWidth: Tokens.measure.barMeterSegmentWidth
        segmentHeight: Tokens.measure.barMeterSegmentHeight
        value: root.charge / 100
        visible: root.unplugged
        // A flat battery is a warning: the lit segments turn accent below 20%.
        // (The pre-pass meter used hotThreshold, which lights *above* it, so
        // any battery over 20% showed in accent.)
        litColor: root.charge < 20 ? Tokens.color.accent : Tokens.color.signal
    }

    Value {
        id: value

        anchors.verticalCenter: parent.verticalCenter
        bar: true
        width: widest.width
        horizontalAlignment: Text.AlignRight
        text: root.unplugged ? Fmt.percent(root.charge) : "AC"

        TextMetrics {
            id: widest
            font: value.font
            text: (root.battery?.isPresent ?? false) ? "100%" : "AC"
        }
    }

    // Opens the power dropdown under this readout. TapHandler rather than a
    // MouseArea, so the Row does not try to lay the handler out as a child.
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }


    // Registered with ShellState so `dropdown open power` can hang the panel where
    // a click would have, on this readout's own screen. The x is measured when
    // it is needed rather than published: see `ShellState.readouts`.
    readonly property string dropdownName: "power"
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    Component.onCompleted: ShellState.registerReadout(root)
    Component.onDestruction: ShellState.unregisterReadout(root)
    TapHandler {
        onTapped: ShellState.toggleDropdown(root)
    }

}
