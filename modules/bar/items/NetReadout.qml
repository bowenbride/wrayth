import QtQuick
import Quickshell
import qs.components
import qs.components.ui
import qs.config
import qs.services
import qs.utils

Row {
    id: root

    spacing: Tokens.space.s8

    // The icon stands in for the word `NET`, so it takes that word's grey by
    // default; only the bars the signal actually reaches take the data
    // colour. A cable lights all four -- the readout is how good the link is,
    // and a cable is as good as it gets.
    WifiGlyph {
        anchors.verticalCenter: parent.verticalCenter
        strength: Wifi.wired ? 1 : Wifi.strength
        active: Wifi.radioOn && (Wifi.connected || Wifi.wired)
    }

    // A VPN is up: a 10 px `lock` icon after the bars, in `signal`.
    Icon {
        anchors.verticalCenter: parent.verticalCenter
        visible: Radio.tunnelUp
        name: "lock"
        size: Tokens.icon.vpnLock
        color: Tokens.color.signal
    }

    // The live traffic graph (DESIGN.md): part of the readout, never
    // removed. Upload in accent, download in signal (DESIGN.md).
    Sparkline {
        anchors.verticalCenter: parent.verticalCenter
        visible: Wifi.radioOn || Wifi.wired
        implicitWidth: Tokens.measure.netGraphWidth
        implicitHeight: Tokens.measure.netGraphHeight
        points: Tokens.measure.netGraphPoints
        downValues: SysInfo.netRxHistory
        upValues: SysInfo.netTxHistory
        upColor: Tokens.color.accent
        downColor: Tokens.color.signal
    }

    // Up and down (DESIGN.md): each a fixed 4-character value (Fmt.rate),
    // right-aligned in a 4-character tabular slot, after its arrow. Upload in
    // accent, download in signal (DESIGN.md).
    component Speed: Row {
        id: speed

        property string arrow: ""
        property string value: ""
        property color tone: Tokens.color.text

        spacing: 0
        visible: Wifi.radioOn || Wifi.wired

        Value {
            anchors.verticalCenter: parent.verticalCenter
            bar: true
            text: speed.arrow
            color: speed.tone
        }
        Value {
            id: figure
            anchors.verticalCenter: parent.verticalCenter
            bar: true
            width: fourChars.advanceWidth
            horizontalAlignment: Text.AlignRight
            text: speed.value
            color: speed.tone

            TextMetrics {
                id: fourChars
                font: figure.font
                text: "0000"
            }
        }
    }

    Speed {
        anchors.verticalCenter: parent.verticalCenter
        arrow: "▲"
        value: Fmt.rate(SysInfo.netTxRate)
        tone: Tokens.color.accent
    }
    Speed {
        anchors.verticalCenter: parent.verticalCenter
        arrow: "▼"
        value: Fmt.rate(SysInfo.netRxRate)
        tone: Tokens.color.signal
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
