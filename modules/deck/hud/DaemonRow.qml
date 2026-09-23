import QtQuick
import qs.components
import qs.config
import qs.services

// One daemon on the HUD: its name and current reading on a single line. A
// click opens the detail view, which the HUD draws in place of the whole
// daemon area -- the row itself no longer expands.
Item {
    id: root

    required property var entry
    readonly property var reading: Daemons.readings[entry.id] ?? null
    readonly property bool expanded: Daemons.expanded === entry.id

    implicitWidth: parent ? parent.width : 0
    implicitHeight: 14

    NrLabel {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.dim
        text: root.entry.name
    }

    Text {
        renderType: Text.NativeRendering
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        text: root.reading?.value ?? "..."
        color: root.reading ? Daemons.toneColor(root.reading.tone) : Theme.mute
        font.family: Appearance.font.data
        font.pixelSize: Appearance.size.label
        font.weight: Appearance.font.weightSemi
        font.letterSpacing: Appearance.tracking(Appearance.size.label)
    }

    Feedback {
        id: feedback

        anchors.fill: parent
        flashOpacity: 0.2
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onPressed: feedback.flash()
        onClicked: Daemons.expanded = root.expanded ? "" : root.entry.id
    }
}
