import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.components
import qs.config
import qs.services

// The system tray: a tray mark and how many apps are in it, in a fixed slot
// that stays reserved when the tray is empty (dimmed then). The apps' own
// icons are never drawn on the bar -- they arrive in every colour there is --
// only in the TRAY dropdown, tinted.
Row {
    id: root

    readonly property int count: Tray.items.length

    spacing: 5
    // The whole readout dimmed when the tray is empty.
    opacity: count > 0 ? 1 : 0.45

    // The tray mark: four squares in a 2 x 2 grid, 13 px, drawn.
    Grid {
        anchors.verticalCenter: parent.verticalCenter
        columns: 2
        spacing: 1

        Repeater {
            model: 4
            Rectangle {
                width: 6
                height: 6
                color: Theme.dim
            }
        }
    }

    Slot {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Appearance.slot.trayCount
        horizontalAlignment: Text.AlignLeft
        text: String(root.count)
        color: Theme.text
        font.pixelSize: 10
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    readonly property string dropdownName: "tray"
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    Component.onCompleted: ShellState.registerReadout(root)
    Component.onDestruction: ShellState.unregisterReadout(root)

    TapHandler {
        onTapped: ShellState.toggleDropdown(root)
    }
}
