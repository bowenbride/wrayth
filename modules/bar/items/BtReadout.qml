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

    spacing: 7

    // The rune stands in for the word `BT`, so it keeps that word's grey in
    // every state. The device name beside it is what carries the reading.
    BluetoothGlyph {
        anchors.verticalCenter: parent.verticalCenter
    }

    // Left-aligned so a short name sits next to the label, but capped at 120px
    // so a long one truncates instead of pushing the ticker around.
    Slot {
        anchors.verticalCenter: parent.verticalCenter

        implicitWidth: Math.min(Appearance.slot.btName, label.implicitWidth)
        horizontalAlignment: Text.AlignLeft

        text: {
            if (!root.adapter || !root.adapter.enabled)
                return "OFF";
            return root.linked ? Demo.device(root.linked.name, 0) : "NONE";
        }
        color: root.linked ? Theme.signal : Theme.dim

        // Measures the untruncated name so the slot can shrink below its cap.
        Text {
            renderType: Text.NativeRendering
            id: label

            visible: false
            text: parent.text
            font: parent.font
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
