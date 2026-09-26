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

    // **Rune alone when the bar runs short** (Bar decides; see
    // `metrics.tickerMin`). The name eases to nothing rather than vanishing,
    // and `fullWidth` is what the readout needs with its name, whichever way
    // it is showing, so the decision never feeds back on itself.
    property bool compact: false
    readonly property real nameWidth: Math.min(Appearance.slot.btName, label.implicitWidth)
    readonly property real fullWidth: rune.implicitWidth + 7 + nameWidth

    spacing: nameSlot.implicitWidth > 0 ? 7 : 0

    // The rune is dim, and takes the bar's value-text colour while a device
    // is connected; off or disconnected, it stays dim. The change eases with
    // the feedback timing.
    BluetoothGlyph {
        id: rune

        anchors.verticalCenter: parent.verticalCenter
        color: root.linked && root.adapter?.enabled ? Theme.text : Theme.dim

        Behavior on color {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }
    }

    // Left-aligned so a short name sits next to the label, but capped at 120px
    // so a long one truncates instead of pushing the ticker around.
    Slot {
        id: nameSlot

        anchors.verticalCenter: parent.verticalCenter
        clip: true
        opacity: root.compact ? 0 : 1

        implicitWidth: root.compact ? 0 : root.nameWidth

        Behavior on implicitWidth {
            NumberAnimation {
                duration: Appearance.duration.move
                easing.type: Easing.OutCubic
            }
        }
        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.duration.move
                easing.type: root.compact ? Easing.InCubic : Easing.OutCubic
            }
        }
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
