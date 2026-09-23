import QtQuick
import qs.components
import qs.config

// The delete question, covering the card it is about. A dialog in the middle
// of the screen would have to name the profile to be clear; a panel over the
// card does not, because the card is still underneath it.
ChamferPanel {
    id: root

    required property string name

    signal confirmed
    signal cancelled

    chamfer: Appearance.chamfer.panel
    fillColor: Qt.rgba(Theme.ground.r, Theme.ground.g, Theme.ground.b, 0.96)
    borderColor: Theme.alert

    // Nothing behind this panel is clickable while it is up.
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
    }

    Column {
        anchors.centerIn: parent
        width: parent.width - 28
        spacing: 12

        Text {
            width: parent.width

            text: `DELETE ${root.name.toUpperCase()}?`
            color: Theme.alert
            font.family: Appearance.font.display
            font.pixelSize: 15
            font.weight: Appearance.font.weightBold
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            renderType: Text.NativeRendering
        }

        Text {
            width: parent.width

            // The second sentence is the one that matters: the wallpaper is a
            // file in the user's own library, and the pools screen is the only
            // place in the shell that deletes one.
            text: "The profile is removed. Its wallpaper stays in your library."
            color: Theme.dim
            font.family: Appearance.font.data
            font.pixelSize: 10
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            renderType: Text.NativeRendering
        }

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10

            ActionButton {
                text: "DELETE"
                accented: true
                textColor: Theme.alert
                onClicked: root.confirmed()
            }

            ActionButton {
                text: "KEEP"
                onClicked: root.cancelled()
            }
        }
    }
}
