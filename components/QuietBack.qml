import QtQuick
import qs.config

// BACK inside a dropdown: always quiet. A chevron and the name of where it
// returns to ("‹ AUDIO", "‹ TRAY", "‹ UPLINK"), dim, with no frame and no
// chamfer. Full-screen views keep the framed BackButton.
Item {
    id: root

    property string label: ""
    signal activated

    implicitWidth: row.implicitWidth
    implicitHeight: 22

    Row {
        id: row

        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron_left"
            size: 16
            color: hover.hovered ? Theme.text : Theme.dim
        }
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.label
            color: hover.hovered ? Theme.text : Theme.dim
            font.family: Appearance.font.data
            font.pixelSize: 10
            font.weight: Appearance.font.weightSemi
            font.letterSpacing: 10 * 0.14
            renderType: Text.NativeRendering
        }
    }
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: root.activated()
    }
}
