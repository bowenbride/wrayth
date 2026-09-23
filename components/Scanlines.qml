import QtQuick
import Quickshell
import qs.config
import qs.services

// The scanline overlay: whatever treatment is set, drawn over one surface.
//
// **One textured quad per surface for the lines, and the texture is drawn
// once.** They are 1 x 3 and 1 x 4 PNGs tiled by the GPU --
// `assets/scanline.png` and `assets/scanline-wide.png`, generated at build
// time rather than painted per frame. The obvious alternative, a `Repeater` of
// `Rectangle`s, is 360 scene-graph nodes a surface for a pattern the texture
// unit draws for free, on a machine with an Intel iGPU and no discrete
// anything.
//
// The rolling band is a second quad with an animation behind it and the
// vignette a third, and both are paid on every surface they are drawn on --
// which is what the EFFECTS page's cost note says.
//
// **It reserves nothing and takes no input.** Turning scanlines off, or
// excluding a surface, changes nothing about layout or spacing: this simply
// stops drawing. It is a sibling laid over its surface's contents, never a
// parent of them, so nothing is inside it and nothing can be moved by it.
Item {
    id: root

    // What this surface is, which decides whether the coverage setting
    // includes it:
    //
    //   "panel"     the shell's panels, the bar, the overlays. On whenever
    //               scanlines are on at all.
    //   "wallpaper" the desktop background. Only under EVERYTHING.
    //   "windows"   the full-screen layer drawn over application windows.
    //               Only when EXCLUDE WINDOW CONTENT is off.
    property string surface: "panel"

    // A treatment key forced on this instance, for the EFFECTS page's preview
    // tiles: they have to show every treatment at once, whatever the setting
    // is. Empty means "follow the setting for this surface".
    property string forced: ""

    readonly property bool previewing: root.forced !== ""
    readonly property var treatment: root.previewing ? Effects.treatmentFor(root.forced) : Effects.treatment

    // The host's veto. A `ChamferPanel` nested inside another turns its own
    // overlay off here rather than being taken out of the tree, so the panel
    // keeps its mask and its geometry either way.
    property bool active: true

    // **The lines are per surface; the band and the vignette are per screen.**
    // A vignette darkens the corners *of the screen*, and drawn into each
    // surface it darkened the corners of each one instead -- on the bar, whose
    // window is 1920 x 44, that meant a heavy shadow along the top and bottom
    // of the ID block. There is no way to map a layer surface into screen
    // coordinates from inside it either: `mapToGlobal` returns the same
    // window-relative point `mapToItem(null)` does. So the two screen effects
    // are drawn by the surfaces that *are* the screen -- the wallpaper layer
    // and, when it exists, the layer over the windows -- and by nothing else.
    readonly property bool screenSurface: root.surface === "wallpaper" || root.surface === "windows"

    readonly property bool linesWanted: {
        if (!root.active)
            return false;
        if (root.previewing)
            return root.treatment.key !== "NONE";
        if (root.surface === "wallpaper")
            return Effects.scanlinesOnWallpaper;
        if (root.surface === "windows")
            return Effects.scanlinesOverWindows;
        return Effects.scanlinesOnPanels;
    }

    readonly property bool bandWanted: root.active && root.treatment.band && Effects.scanlinesOn && (root.previewing || root.screenSurface)
    readonly property bool vignetteWanted: root.active && root.treatment.vignette && Effects.scanlinesOn && (root.previewing || root.screenSurface)

    readonly property bool wanted: root.linesWanted || root.bandWanted || root.vignetteWanted

    anchors.fill: parent
    // Never in the way of the pointer, whatever it is laid over.
    enabled: false
    // An invisible item costs nothing, and the fade is what stops the lines
    // snapping in when the setting changes.
    visible: opacity > 0
    opacity: root.wanted ? 1 : 0

    Behavior on opacity {
        NumberAnimation {
            duration: root.wanted ? Appearance.duration.enter : Appearance.duration.exit
            easing.type: root.wanted ? Easing.OutCubic : Easing.InCubic
        }
    }

    // --- The lines --------------------------------------------------------------
    Image {
        anchors.fill: parent
        visible: root.linesWanted
        opacity: root.treatment.strength
        // **A url, not a path.** `shellPath` returns a filesystem path and
        // `Image.source` wants a url; handed the bare path the image silently
        // failed to load and the overlay drew nothing at all.
        source: Paths.url(Quickshell.shellPath(root.treatment.pitch === 4 ? "assets/scanline-wide.png" : "assets/scanline.png"))
        fillMode: Image.Tile
        // **Neither smoothed nor mipmapped.** A 1 px line filtered is a 3 px
        // grey smear, which is a different effect and a worse one.
        smooth: false
        mipmap: false
        cache: true
    }

    // --- The rolling band --------------------------------------------------------
    // A soft bright band drifting down the screen every 7 seconds. It is
    // positioned from the shared phase against this surface's own place in the
    // window, so every surface shows the same band in the same place at the
    // same moment.
    Item {
        id: band

        // **A preview tile cycles the band within itself.** On a real surface
        // the band crosses the whole screen, so a 150 px tile would show it
        // for a second and a half of every seven and look broken the rest of
        // the time; a preview has to show what it is previewing.
        readonly property real travel: root.height + height

        anchors.left: parent.left
        anchors.right: parent.right
        height: root.previewing ? 46 : 90
        visible: root.bandWanted
        y: Effects.bandPhase * travel - height

        // The shared clock only runs while something is drawing a band.
        onVisibleChanged: Effects.holdBand(visible)
        Component.onCompleted: if (visible) Effects.holdBand(true)
        Component.onDestruction: if (visible) Effects.holdBand(false)

        Rectangle {
            anchors.fill: parent

            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.5
                    color: Qt.rgba(1, 1, 1, 0.055)
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }
    }

    // --- The vignette -------------------------------------------------------------
    // A radial alpha ramp, a soft gradient being the one thing that survives
    // being scaled -- which is why this is a small texture rather than a
    // shader.
    //
    // **It is one vignette on the screen, not one on each panel.** Filled to
    // each surface it darkened the corners of every panel in the shell
    // separately, which is a different effect and a silly one; it is sized and
    // placed in window coordinates so each surface draws its own slice of the
    // same ramp. A preview tile is the exception: it is showing what the whole
    // screen would look like, so its vignette is its own.
    Image {
        anchors.fill: parent
        visible: root.vignetteWanted
        source: Paths.url(Quickshell.shellPath("assets/vignette.png"))
        fillMode: Image.Stretch
        smooth: true
        // **Not cached.** Qt's pixmap cache keys on the url, and this texture
        // is regenerated in place when its strength is retuned -- so a running
        // shell kept serving the first build of it and every measurement of
        // the "new" vignette was a measurement of the old one. It took
        // isolating the treatments one at a time to see it: `CRT` darkened the
        // ID block to 40 of 255 where the strength in the file said 207.
        // There are two of these on a screen at most; there is nothing here
        // worth caching.
        cache: false
    }
}
