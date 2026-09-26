import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs.components
import qs.config
import qs.services

Row {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var linked: {
        const devices = Bluetooth.devices?.values ?? [];
        for (const device of devices) {
            if (device.connected)
                return device;
        }
        return null;
    }

    // BLUETOOTH (DESIGN.md): the rune only. `compact` and `fullWidth` stay
    // for the bar's width logic; with no name there is nothing to hide.
    property bool compact: false
    readonly property real fullWidth: implicitWidth

    BluetoothGlyph {
        id: rune

        anchors.verticalCenter: parent.verticalCenter
        color: root.linked && root.adapter?.enabled ? Tokens.color.text : Tokens.color.dim

        Behavior on color {
            ColorAnimation {
                duration: Tokens.motion.feedback
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeIn
            }
        }
    }

    // Opens the bluetooth dropdown under this readout. TapHandler rather than a
    // MouseArea, so the Row does not try to lay the handler out as a child.
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }


    // Registered with ShellState so `dropdown open bluetooth` can hang the panel where
    // a click would have, on this readout's own screen. The x is measured when
    // it is needed rather than published: see `ShellState.readouts`.
    readonly property string dropdownName: "bluetooth"
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    Component.onCompleted: ShellState.registerReadout(root)
    Component.onDestruction: ShellState.unregisterReadout(root)
    TapHandler {
        onTapped: ShellState.toggleDropdown(root)
    }

}
