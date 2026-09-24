import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs.components
import qs.config
import qs.services
import qs.utils

Row {
    id: root

    readonly property var battery: UPower.displayDevice
    // UPower reports percentage as 0..1.
    readonly property real charge: (battery?.percentage ?? 0) * 100
    readonly property bool unplugged: UPower.onBattery && (battery?.isPresent ?? false)

    spacing: 7

    NrLabel {
        anchors.verticalCenter: parent.verticalCenter
        text: "PWR"
    }

    SegmentMeter {
        anchors.verticalCenter: parent.verticalCenter
        visible: root.unplugged

        segments: Appearance.metrics.meterSegments
        segmentWidth: Appearance.metrics.meterSegmentWidth
        segmentHeight: Appearance.metrics.meterSegmentHeight
        value: root.charge / 100
        litColor: Theme.signal
        // A flat battery is the one thing here worth shouting about.
        hotThreshold: 0.2
        hotColor: Theme.accent
    }

    Slot {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: root.unplugged ? Appearance.slot.percent : acLabel.implicitWidth
        text: root.unplugged ? Fmt.percent(root.charge) : "AC"

        Text {
            renderType: Text.NativeRendering
            id: acLabel

            visible: false
            text: "AC"
            font: parent.font
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
