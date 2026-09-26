import QtQuick
import qs.components
import qs.config
import qs.services
import qs.utils

// The volume / brightness readout: a title row and a 20-segment bar --
// one segment per 5% step, so a single key press fills or empties exactly one.
ChamferPanel {
    id: root

    required property bool volume
    // The track, briefly, on a media key: the panel keeps its size and swaps
    // its meter for the title.
    property bool media: false
    readonly property var player: Media.player

    readonly property bool muted: volume && !media && Audio.muted
    readonly property real level: volume ? Audio.volume : Brightness.value

    readonly property real padding: 14

    chamfer: Appearance.chamfer.panel
    fillColor: Theme.panel2
    borderColor: root.muted ? Theme.accent : Theme.hair

    Item {
        id: line

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.padding
        height: 18

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            Text {
                id: osdTitle

                anchors.verticalCenter: parent.verticalCenter
                text: root.media ? (root.player?.isPlaying ? "PLAY" : "PAUSED") : (root.volume ? "VOL" : "BRI")
                color: Theme.bright
                font.family: Appearance.font.display
                font.pixelSize: 14
                font.weight: Appearance.font.weightBold
                renderType: Text.NativeRendering
            }

            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: root.media ? Media.appOf(root.player).toUpperCase() : (root.volume ? Audio.deviceName : Brightness.outputName)
            }

            KanaTag {
                anchors.verticalCenter: parent.verticalCenter
                text: root.media ? "再生" : (root.volume ? "音量" : "輝度")
                title: osdTitle
            }
        }

        Text {
            renderType: Text.NativeRendering
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter

            opacity: root.media ? 0 : 1
            text: root.muted ? "MUTED" : Fmt.percent(root.level * 100)
            color: root.muted ? Theme.accent : Theme.bright
            font.family: Appearance.font.data
            font.pixelSize: Appearance.size.body
            font.weight: Appearance.font.weightSemi
        }
    }

    SegmentMeter {
        id: bar

        anchors.top: line.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding

        // 20, not 25: both keys step 5%, and 100 / 5 is 20. At 25 a press moved
        // 1.25 segments and the bar stuttered against the number beside it.
        // The popup keeps its width; the segments widen to fill it.
        segments: 20
        spacing: 3
        segmentWidth: (width - (segments - 1) * spacing) / segments
        segmentHeight: 10
        value: root.level
        litColor: root.muted ? Theme.mute : Theme.accent
        animate: false
        opacity: root.media ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }
    }

    // In media mode: the track and who it is by, where the meter was.
    Text {
        anchors.top: line.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        opacity: root.media ? 1 : 0
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: [root.player?.trackTitle, root.player?.trackArtist].filter(t => t).join(" / ") || "NOTHING PLAYING"
        color: Theme.bright
        font.family: Appearance.font.data
        font.pixelSize: Appearance.size.body
        font.weight: Appearance.font.weightSemi
        renderType: Text.NativeRendering

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }
    }

    // The spec's "slight glow" on the bar.
}
