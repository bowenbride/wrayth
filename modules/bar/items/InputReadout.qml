import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// The input mode: EN, あ, ア or the layout's code, in a slot at least 34 px
// wide. Only there with two or more layouts or an input method (StatusItems
// hides it, and its divider, otherwise).
Item {
    id: root

    implicitWidth: Math.max(34, label.implicitWidth)
    implicitHeight: label.implicitHeight

    Text {
        id: label

        anchors.centerIn: parent
        text: InputModes.glyph
        color: Theme.text
        font.family: Appearance.font.data
        font.pixelSize: 11
        font.weight: Appearance.font.weightSemi
        renderType: Text.NativeRendering
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    readonly property string dropdownName: "input"
    readonly property string screenName: QsWindow.window?.screen?.name ?? ""

    Component.onCompleted: ShellState.registerReadout(root)
    Component.onDestruction: ShellState.unregisterReadout(root)

    TapHandler {
        onTapped: ShellState.toggleDropdown(root)
    }
}
