import QtQuick
import qs.config

// BackControl (DESIGN.md).
//   In a dropdown (default): a quiet button, `chevron_left` plus the name of
//   where it returns to (AUDIO, TRAY, UPLINK). Never framed, never chamfered,
//   never the word BACK alone.
//   In a full-screen view (`fullScreen`): a secondary button reading BACK with
//   an ESC keycap, 22 px, with a 5 px top-left chamfer. Does what Escape does.
Item {
    id: root

    property string destination: ""
    property bool fullScreen: false
    signal activated

    implicitWidth: fullScreen ? full.implicitWidth : quiet.implicitWidth
    implicitHeight: Tokens.measure.buttonInline

    Button {
        id: quiet
        visible: !root.fullScreen
        kind: "quiet"
        chevron: "left"
        text: root.destination
        onClicked: root.activated()
    }

    Item {
        id: full

        visible: root.fullScreen
        implicitWidth: back.implicitWidth + Tokens.space.s6 + esc.implicitWidth + Tokens.space.s8
        implicitHeight: Tokens.measure.buttonInline

        Button {
            id: back
            kind: "secondary"
            inline: true
            text: "BACK"
            cutTopLeft: Tokens.chamfer.backControl
            width: parent.width
            onClicked: root.activated()
        }
        Keycap {
            id: esc
            anchors.right: parent.right
            anchors.rightMargin: Tokens.space.s4
            anchors.verticalCenter: parent.verticalCenter
            text: "ESC"
        }
    }
}
