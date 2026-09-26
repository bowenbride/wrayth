import QtQuick
import qs.components
import qs.config
import qs.utils

// One result: index, icon badge, name, category tag, and EXEC on the selected
// row. A profile entry has no icon, so its badge falls back to two letters.
Item {
    id: root

    required property var result
    required property int index
    required property bool selected

    signal activated

    implicitHeight: 44

    Rectangle {
        anchors.fill: parent
        color: root.selected ? Tokens.color.accentTint : "transparent"
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 2
        color: Tokens.color.accent
        visible: root.selected
    }

    NrLabel {
        id: number

        anchors.left: parent.left
        anchors.leftMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        color: root.selected ? Tokens.color.accent : Tokens.color.mute
        text: Fmt.pad2(root.index + 1)
    }

    ChamferPanel {
        id: badge

        anchors.left: number.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 28
        height: 22

        chamfer: 5
        // Filled accent when selected, so the letters read as cut out of it.
        fillColor: root.selected ? Tokens.color.accent : Theme.cell
        borderColor: root.selected ? Tokens.color.accent : Tokens.color.hair

        // Two letters, never an icon: the mockup has no icons here.
        Text {
            anchors.centerIn: parent

            text: root.result.name.replace(/[^A-Za-z0-9]/g, "").slice(0, 2).toUpperCase()
            color: root.selected ? Tokens.color.ground : Tokens.color.dim
            font.family: Tokens.font.data
            font.pixelSize: 10
            font.weight: Appearance.font.weightBold
            renderType: Text.NativeRendering
        }
    }

    Text {
        anchors.left: badge.right
        anchors.leftMargin: 12
        anchors.right: tag.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter

        text: root.result.name
        color: root.selected ? Tokens.color.bright : Tokens.color.text
        font.family: Tokens.font.data
        font.pixelSize: Appearance.size.body
        elide: Text.ElideRight
        maximumLineCount: 1
        renderType: Text.NativeRendering
    }

    NrLabel {
        id: tag

        anchors.right: exec.left
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        color: Tokens.color.mute
        text: root.result.tag
    }

    // EXEC and the key that does it. The keycap replaced a bare `⏎`, which at
    // this size was a handful of grey pixels nobody could read.
    Row {
        id: exec

        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        visible: root.selected

        NrLabel {
            anchors.verticalCenter: parent.verticalCenter
            color: Tokens.color.accent
            text: "EXEC"
        }

        Keycap {
            anchors.verticalCenter: parent.verticalCenter
            key: "ENTER"
            color: Tokens.color.accent
        }
    }

    // The row wears the bloom as one piece, so the cap's border glows with the
    // word beside it rather than sitting flat against it.

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    Feedback {
        id: feedback

        anchors.fill: parent
        flashOpacity: 0.22
    }

    TapHandler {
        onPressedChanged: if (pressed) feedback.flash()
        // A frame for the flash before the launcher closes over it, which is
        // the whole point of flashing the row at all.
        onTapped: defer.restart()
    }

    Timer {
        id: defer

        interval: 16
        onTriggered: root.activated()
    }
}
