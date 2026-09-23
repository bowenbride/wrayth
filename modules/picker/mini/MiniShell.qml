import QtQuick
import qs.components
import qs.config

// A profile's card thumbnail: its wallpaper with a miniature of the interface
// drawn over it in that profile's colours. What a swatch row cannot say -- how
// the accent sits on the panel, whether the dim labels survive the ground --
// this says for all eight profiles at once, without recolouring the shell to
// find out.
Item {
    id: root

    required property var palette
    property bool active: false
    property url image
    // Everything but the previewed card sits back, image and interface alike:
    // dimming only the photograph would leave eight equally bright miniatures
    // competing with the one that is selected.
    property bool dimmed: false

    clip: true

    // The ground goes underneath rather than beside: a card's image changes
    // when its star moves or its pool turns over, and the crossfade needs
    // something to fade *from* when the old one is gone.
    Rectangle {
        anchors.fill: parent
        color: root.palette.ground
    }

    // `Wallpaper`, so a card's image crossfades like every other wallpaper in
    // the shell rather than cutting.
    //
    // **Blurred and dimmed, because the card is answering a question about the
    // interface.** A sharp photograph behind 7 px type is texture the type has
    // to be read through: the mini bar's ID block and the SYS.DIAG panel's
    // lines were sitting on whatever the wallpaper happened to be doing under
    // them. 4 px of blur takes the detail out without taking the image away --
    // it still reads as an image, which is the other half of what the card is
    // choosing between -- and 60% brightness puts it behind the ink rather
    // than beside it.
    Wallpaper {
        anchors.fill: parent
        source: root.image
        blurRadius: 4
        dim: 0.4
    }

    // **No transform.** The miniature used to be drawn into a wrapper sized at
    // 1/1.35 of the thumbnail and scaled back up, which rasterised every glyph
    // in it at the small size and then magnified the result -- and the card's
    // thumbnail is inside a `layer` for its chamfer mask, so the magnification
    // happened to an already-flattened texture. It measured the right size and
    // could not be read.
    //
    // Both children are authored at the size they are drawn now. The rule this
    // leaves behind: **nothing in this shell is drawn small and scaled up.**
    MiniBar {
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        palette: root.palette
        active: root.active
    }

    // 5 px under the strip and 4 px clear of the thumbnail's bottom edge. At
    // 30 the panel's own border landed on the card's accent line and the two
    // read as one thick rule; the 135 px thumbnail has exactly this much to
    // give, which is why the panel is 104 rather than whatever a naive 1.35
    // would have made it.
    MiniDiag {
        anchors.top: parent.top
        anchors.topMargin: 27
        anchors.right: parent.right
        anchors.rightMargin: 11
        palette: root.palette
    }

    // **0.38, not 0.55.** The wallpaper underneath is already dimmed to 60%
    // now; at 0.55 on top of that an unpreviewed card's image came out at a
    // quarter brightness and read as a black rectangle, which is the one thing
    // the card must not do -- the image is half of what is being chosen. The
    // previewed card still stands clear of the other seven.
    Rectangle {
        anchors.fill: parent
        color: "black"
        opacity: root.dimmed ? 0.38 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }
    }
}
