import QtQuick
import QtMultimedia

// A video wallpaper: muted, looping, drawn over its first-frame still, and
// paused whenever `playing` is false (Wallpaper.qml decides).
Item {
    id: root

    property url source
    property bool playing: false

    MediaPlayer {
        id: player

        source: root.source
        loops: MediaPlayer.Infinite
        videoOutput: out
        audioOutput: null
        Component.onCompleted: if (root.playing) play()
    }
    onPlayingChanged: playing ? player.play() : player.pause()

    VideoOutput {
        id: out

        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectCrop
    }
}
