import QtQuick
import QtQuick.Effects
import qs.config
import qs.services

// The wallpaper, crossfading whenever it changes. Used crisp on the desktop
// background and blurred/dimmed behind the deck, lock and overlays.
//
// **The default source is the one the shell is showing**, not the profile's
// file: which wallpaper that is -- the profile's own, one of its pool, or a
// locked one the profile no longer governs -- is `Wallpapers`' business, and
// routing every surface through it is what makes "nothing ever cuts or blinks"
// a property of the shell rather than a thing each caller remembers.
Item {
    id: root

    property url source: Wallpapers.displayed

    // 0 = crisp. The spec's blurred backdrops ask for about 16.
    property real blurRadius: 0
    // 0 = full brightness, 0.58 gives the spec's "about 42% brightness".
    property real dim: 0

    // Video wallpapers: only a surface that allows it plays one (the desktop
    // background), and only while `videoPlaying`; everything else shows the
    // video's first frame.
    property bool allowVideo: false
    property bool videoPlaying: false

    // The pool's own fade, so a slow shuffle drifts rather than cuts.
    property int fadeDuration: Wallpapers.fadeDuration

    // Blur and dim are animated so the desktop can settle between crisp and
    // quiet as windows come and go.
    Behavior on blurRadius {
        NumberAnimation {
            duration: Tokens.motion.panels
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.motion.easeIn
        }
    }

    Behavior on dim {
        NumberAnimation {
            duration: Tokens.motion.panels
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.motion.easeIn
        }
    }

    // `front` is the image being shown; `back` is the one fading out under it.
    property url frontSource: source
    property url backSource: source
    property real mix: 1

    onSourceChanged: {
        if (source === frontSource)
            return;
        // **Nothing may leave the new wallpaper hidden under the old one.** The
        // old image moves to the back first, then `mix` drops, and only then
        // does the front take the new source: a cached image can report Ready
        // during that assignment, and the fade below starts only while `mix`
        // is below 1. A cached image can also be Ready with no status change
        // at all, so the fade is checked once more after the change settles.
        backSource = frontSource;
        mix = 0;
        frontSource = source;
        Qt.callLater(root.startFadeIfReady);
    }

    function startFadeIfReady(): void {
        if (root.mix < 1 && (front.status === Image.Ready || front.status === Image.Error) && !fade.running)
            fade.restart();
    }

    Item {
        id: layers

        anchors.fill: parent
        layer.enabled: root.blurRadius > 0
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: Math.min(1, root.blurRadius / 64)
            blurMax: 64
            autoPaddingEnabled: false
        }

        Image {
            anchors.fill: parent
            source: Wallpapers.stillOf(root.backSource)
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(root.width, root.height)
            asynchronous: true
            cache: true
        }

        Image {
            id: front

            anchors.fill: parent
            source: Wallpapers.stillOf(root.frontSource)
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(root.width, root.height)
            asynchronous: true
            cache: true
            opacity: root.mix

            // Only start the crossfade once the new image is actually decoded,
            // so a swap never flashes the layer underneath.
            // A file that fails to load fades in too, so the old wallpaper
            // never stays on screen for a profile it no longer belongs to.
            onStatusChanged: {
                if ((status === Image.Ready || status === Image.Error) && root.mix < 1)
                    fade.restart();
            }
        }
    }

    // The video itself, over its still once the crossfade is done. Muted,
    // looping, paused (on its current frame) whenever it should not play.
    Loader {
        anchors.fill: parent
        active: root.allowVideo && Wallpapers.isVideo(root.frontSource) && root.mix >= 1
        sourceComponent: VideoWall {
            source: root.frontSource
            playing: root.videoPlaying
        }
    }

    NumberAnimation {
        id: fade

        target: root
        property: "mix"
        to: 1
        duration: root.fadeDuration
        easing.type: Easing.BezierSpline
        easing.bezierCurve: Tokens.motion.easeIn
    }

    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.dim
    }
}
