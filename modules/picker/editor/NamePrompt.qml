import QtQuick
import qs.components
import qs.config
import qs.services

// NAME // PROFILE. The last thing between an edited palette and a profile.
//
// It shows the wallpaper filename it is about to generate, because that file
// is the one lasting consequence of the name -- everything else about a
// profile can be edited afterwards, and the file on disk is what the pools
// screen will list.
ChamferPanel {
    id: root

    // The profile being renamed-into-existence. A rename of an existing custom
    // is not offered: the name is the wallpaper's name too.
    property string value: ""

    signal accepted(string name)
    signal cancelled

    readonly property string trimmed: value.trim()
    readonly property bool badCharacters: trimmed.length > 0 && !/^[A-Za-z0-9 -]+$/.test(trimmed)
    readonly property bool taken: trimmed.length > 0 && Profiles.names.some(name => name.toLowerCase() === trimmed.toLowerCase())
    readonly property bool valid: trimmed.length > 0 && !badCharacters && !taken

    readonly property string filename: `net-${trimmed.toLowerCase().replace(/ +/g, "-")}.png`

    function take(): void {
        field.take();
    }

    implicitWidth: 460
    implicitHeight: 230

    chamfer: Appearance.chamfer.panel
    fillColor: Qt.rgba(Theme.ground.r, Theme.ground.g, Theme.ground.b, 0.97)
    borderColor: Theme.accent

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.AllButtons
    }

    Column {
        anchors.fill: parent
        anchors.margins: 20
        spacing: 12

        Row {
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: `NAME${Appearance.separator}PROFILE`
                color: Theme.bright
                font.family: Appearance.font.display
                font.pixelSize: 18
                font.weight: Appearance.font.weightBold
                renderType: Text.NativeRendering
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "名前"
                color: Theme.signal
                font.family: Appearance.font.accent
                font.pixelSize: Appearance.size.katakana
                font.weight: Appearance.font.weightMedium
                renderType: Text.NativeRendering
            }
        }

        InputField {
            id: field

            width: parent.width
            pixelSize: 13
            maximumLength: 24
            placeholder: "UP TO 24 CHARACTERS"
            text: root.value

            onEdited: v => root.value = v
            onAccepted: if (root.valid) root.accepted(root.trimmed)
            onEscaped: root.cancelled()
        }

        Row {
            spacing: 8

            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.dim
                text: "WALLPAPER"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.trimmed ? root.filename : "net-<name>.png"
                color: root.trimmed ? Theme.signal : Theme.mute
                font.family: Appearance.font.data
                font.pixelSize: 11
                renderType: Text.NativeRendering
            }
        }

        // One line, and only when there is something to say. Letters, numbers,
        // spaces and hyphens are what a filename can carry without quoting.
        NrLabel {
            width: parent.width
            color: Theme.alert
            pixelSize: 10
            text: {
                if (root.badCharacters)
                    return "LETTERS, NUMBERS, SPACES AND HYPHENS ONLY";
                if (root.taken)
                    return `${root.trimmed.toUpperCase()} IS ALREADY A PROFILE`;
                return "";
            }
        }

        Row {
            anchors.right: parent.right
            spacing: 10

            ActionButton {
                text: "CANCEL"
                onClicked: root.cancelled()
            }

            ActionButton {
                text: "SAVE"
                accented: root.valid
                usable: root.valid
                onClicked: root.accepted(root.trimmed)
            }
        }
    }
}
