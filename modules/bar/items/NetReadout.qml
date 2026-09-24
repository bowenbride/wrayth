import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services
import qs.utils

Row {
    id: root

    spacing: 7

    // The icon stands in for the word `NET`, so it takes that word's grey by
    // default; only the bars the signal actually reaches take the data
    // colour. A cable lights all four -- the readout is how good the link is,
    // and a cable is as good as it gets.
    WifiGlyph {
        anchors.verticalCenter: parent.verticalCenter
        strength: Wifi.wired ? 1 : Wifi.strength
        active: Wifi.radioOn && (Wifi.connected || Wifi.wired)
    }

    Sparkline {
        anchors.verticalCenter: parent.verticalCenter
        visible: Wifi.radioOn || Wifi.wired
        implicitWidth: 48
        implicitHeight: 16
        points: 12
        downValues: SysInfo.netRxHistory
        upValues: SysInfo.netTxHistory
    }

    Slot {
        anchors.verticalCenter: parent.verticalCenter
        visible: Wifi.radioOn || Wifi.wired
        implicitWidth: Appearance.slot.netRate
        text: `▲${Fmt.rate(SysInfo.netTxRate)}`
        color: Theme.accent
    }

    Slot {
        anchors.verticalCenter: parent.verticalCenter
        visible: Wifi.radioOn || Wifi.wired
        implicitWidth: Appearance.slot.netRate
        text: `▼${Fmt.rate(SysInfo.netRxRate)}`
        color: Theme.signal
    }

    // Opens the wifi dropdown under this readout. TapHandler rather than a
    // MouseArea, so the Row does not try to lay the handler out as a child.
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }


    // Registered with ShellState so `dropdown open wifi` can hang the panel where
    // a click would have, on this readout's own screen. The x is measured when
    // it is needed rather than published: see `ShellState.readouts`.
    readonly property string dropdownName: "wifi"
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    Component.onCompleted: ShellState.registerReadout(root)
    Component.onDestruction: ShellState.unregisterReadout(root)
    TapHandler {
        onTapped: ShellState.toggleDropdown(root)
    }

}
