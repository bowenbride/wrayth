import QtQuick
import qs.components
import qs.components.ui as UI
import qs.config
import qs.services
import qs.utils

// The on-screen popup (DESIGN.md): volume, brightness, output switching and
// track changes. 12 px chamfers, `panel2`. One line -- a Label and the name
// on the left, the Value on the right -- and a SegmentMeter (12 px) below.
// A track change swaps the meter for the track, title · artist.
ChamferPanel {
    id: root

    required property bool volume
    property bool media: false
    readonly property var player: Media.player

    readonly property bool muted: volume && !media && Audio.muted
    readonly property real level: volume ? Audio.volume : Brightness.value

    readonly property real padding: Tokens.measure.dropdownPadding

    chamfer: Tokens.chamfer.dropdown
    fillColor: Tokens.color.panel2
    borderColor: Tokens.color.hair

    Item {
        id: line

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.padding
        height: value.implicitHeight

        Row {
            anchors.left: parent.left
            anchors.right: value.left
            anchors.rightMargin: Tokens.space.s8
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.space.s8
            clip: true

            UI.Label {
                anchors.verticalCenter: parent.verticalCenter
                text: root.media ? (root.player?.isPlaying ? "PLAYING" : "PAUSED") : (root.volume ? "VOLUME" : "BRIGHTNESS")
            }
            Text {
                readonly property var role: Tokens.type.rowName
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - x)
                elide: Text.ElideRight
                text: root.media ? Media.appOf(root.player).toUpperCase() : (root.volume ? Audio.deviceName : Brightness.outputName)
                textFormat: Text.PlainText
                color: Tokens.color.text
                font.family: role.family
                font.pixelSize: role.size
                renderType: Text.NativeRendering
            }
        }

        UI.Value {
            id: value

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            opacity: root.media ? 0 : 1
            // Muted is a warning state: alert, never the accent.
            text: root.muted ? "MUTED" : Fmt.percent(root.level * 100)
            color: root.muted ? Tokens.color.alert : Tokens.color.text
        }
    }

    UI.SegmentMeter {
        anchors.top: line.bottom
        anchors.topMargin: Tokens.space.s10
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        large: true
        value: root.level
        muted: root.muted
        opacity: root.media ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.motion.feedback
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeIn
            }
        }
    }

    // A track change: the track where the meter was.
    Text {
        readonly property var role: Tokens.type.body
        anchors.top: line.bottom
        anchors.topMargin: Tokens.space.s8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        opacity: root.media ? 1 : 0
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: [root.player?.trackTitle, root.player?.trackArtist].filter(t => t).join(" · ") || "NOTHING PLAYING"
        color: Tokens.color.bright
        font.family: role.family
        font.pixelSize: role.size
        renderType: Text.NativeRendering

        Behavior on opacity {
            NumberAnimation {
                duration: Tokens.motion.feedback
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeIn
            }
        }
    }
}
