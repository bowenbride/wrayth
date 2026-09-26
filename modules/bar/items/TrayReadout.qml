import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import qs.components
import qs.config
import qs.services

// The system tray: its icon only, with a dot while an app asks for attention.
// The apps' own icons are never drawn -- they arrive in every colour there is
// and render badly small -- the TRAY dropdown gives each a two-letter badge.
Row {
    id: root

    readonly property int count: Tray.items.length

    // The tray icon only (Material Symbols Sharp `inbox`), dim, and a 5 x 5
    // accent dot on its top right while an app asks for attention.
    readonly property bool attention: Tray.items.some(i => Tray.wantsAttention(i))

    Item {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: 16
        implicitHeight: 16

        Icon {
            anchors.fill: parent
            name: "inbox"
            size: 16
            color: Theme.dim
        }
        Rectangle {
            visible: root.attention
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -2
            anchors.topMargin: -2
            width: 5
            height: 5
            color: Theme.accent
        }
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
