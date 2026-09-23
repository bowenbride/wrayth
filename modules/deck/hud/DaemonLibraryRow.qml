import QtQuick
import qs.components
import qs.config
import qs.services

// One daemon in the library: a tickbox, its name, and the one line that says
// what it is for.
Item {
    id: root

    required property var entry
    readonly property bool on: Daemons.isSelected(entry.id)
    // At the cap the unselected ones dim: still listed, not selectable.
    readonly property bool available: on || !Daemons.atCap()

    implicitHeight: 26

    Rectangle {
        anchors.fill: parent
        color: root.on ? Theme.alpha(Theme.accent, 0.06) : "transparent"
    }

    Tickbox {
        id: box

        anchors.left: parent.left
        anchors.leftMargin: 2
        anchors.verticalCenter: parent.verticalCenter

        checked: root.on
        active: root.available
        onToggled: if (root.available) Daemons.toggle(root.entry.id)
    }

    NrLabel {
        id: name

        anchors.left: box.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter

        width: 110
        color: root.on ? Theme.bright : (root.available ? Theme.text : Theme.mute)
        text: root.entry.name
    }

    NrLabel {
        anchors.left: name.right
        anchors.leftMargin: 8
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        color: root.available ? Theme.dim : Theme.mute
        elide: Text.ElideRight
        font.capitalization: Font.MixedCase
        text: root.entry.description
    }
}
