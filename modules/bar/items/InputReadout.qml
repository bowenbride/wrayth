import QtQuick
import Quickshell
import qs.components.ui
import qs.config
import qs.services

// The input mode: EN, あ, ア or the layout's code, in a slot at least 34 px
// wide. Only there with two or more layouts or an input method (StatusItems
// hides it, and its divider, otherwise).
Item {
    id: root

    // DESIGN.md: EN, あ or ア as a bar Value, in a 34 px minimum slot.
    implicitWidth: Math.max(Tokens.measure.inputSlot, label.implicitWidth)
    implicitHeight: label.implicitHeight

    Value {
        id: label

        anchors.centerIn: parent
        bar: true
        text: InputModes.glyph
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
