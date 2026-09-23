import QtQuick
import qs.components
import qs.config
import qs.services

// The top bar, drawn small, in a palette that is not necessarily the one the
// shell is wearing. Everything here takes its colour from `palette` rather
// than from `Theme`, which is the whole point: eight of these sit on the
// picker at once, each showing what its own profile would look like.
//
// It is drawn rather than captured. A live copy of the real bar would need
// eight more of every service behind it; the shapes and the palette are what
// the card is answering, and those cost nothing per frame.
//
// **Every figure here is authored at the size it is drawn.** It used to be
// authored at 1/1.35 and scaled up by a transform, which rasterised 7 px type
// and then magnified it -- inside the thumbnail's chamfer layer, so the
// magnification happened to an already-flattened texture. It measured the
// right size and could not be read. Nothing in this shell is drawn small and
// scaled up.
Item {
    id: root

    required property var palette
    // The active profile's card wears its badge *inside* this strip, in the
    // space between the workspaces and the clock. It used to sit on top of the
    // strip, taller than it, covering the ID block and making the active
    // card's header read as a different size from every other card's.
    property bool active: false

    implicitHeight: 22

    Rectangle {
        anchors.fill: parent
        color: root.palette.barBg
    }

    // The ID block, with the user's real code and suffix -- not a placeholder.
    // The card is showing them their bar, and their ID block is part of it.
    Row {
        id: ident

        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        spacing: 0

        Rectangle {
            width: code.implicitWidth + 9
            height: parent.height
            color: root.palette.accent

            Text {
                id: code

                anchors.centerIn: parent
                text: Runner.code
                color: root.palette.ground
                font.family: Appearance.font.data
                font.pixelSize: 11
                font.weight: Appearance.font.weightBold
                renderType: Text.NativeRendering
            }
        }

        Rectangle {
            width: suffix.implicitWidth + 8
            height: parent.height
            color: root.palette.accent

            Text {
                id: suffix

                anchors.centerIn: parent
                text: `//${Runner.suffix}`
                // The real block draws this as `ground` at 55% over the
                // accent; at this size that blend is what keeps the slashes
                // from closing up into a smudge.
                // `Theme.alpha` rather than `Qt.rgba` off the token: a
                // palette handed in as data holds hex *strings*, which have no
                // `.r`. The helper's parameter is typed `color`, so a string
                // and a colour both arrive as one.
                color: Theme.alpha(root.palette.ground, 0.55)
                font.family: Appearance.font.data
                font.pixelSize: 11
                font.weight: Appearance.font.weightBold
                renderType: Text.NativeRendering
            }
        }
    }

    // The page marker's pips, at the rest state the bar itself sits at.
    Row {
        id: pips

        anchors.left: ident.right
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3

        Repeater {
            model: 3

            Rectangle {
                required property int index

                width: 4
                height: 4
                color: index === 0 ? root.palette.accent : root.palette.hair
            }
        }
    }

    // --- Workspaces -----------------------------------------------------------
    // **The row shows as many slots as fit, and never a partial one.** At
    // 238 px the strip cannot hold the ID block, the pips, five slots, the
    // badge and the clock at once -- the badge alone is 57 px -- so the count
    // is computed from the room between the pips and whatever comes next: the
    // badge on the active card, the clock on every other one. Five normally,
    // two on the active card. A shorter row reads as a machine with fewer
    // workspaces; a clipped slot reads as a rendering fault.
    Row {
        id: spaces

        readonly property int slotWidth: 16
        readonly property int slotHeight: 14
        readonly property int gap: 3
        // Where the row has to stop.
        readonly property real limit: (root.active ? activeBadge.x : clock.x) - 6
        readonly property int fits: Math.max(0, Math.min(5, Math.floor((limit - x + gap) / (slotWidth + gap))))

        anchors.left: pips.right
        anchors.leftMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        spacing: gap

        Repeater {
            model: spaces.fits

            Rectangle {
                required property int index

                readonly property bool lit: index === 0

                width: spaces.slotWidth
                height: spaces.slotHeight
                color: lit ? Theme.alpha(root.palette.accent, 0.18) : "transparent"
                border.width: Appearance.metrics.hairline
                border.color: lit ? root.palette.accent : "transparent"

                Text {
                    anchors.centerIn: parent
                    text: `0${parent.index + 1}`
                    color: parent.lit ? root.palette.accent : root.palette.dim
                    font.family: Appearance.font.data
                    font.pixelSize: 9
                    font.weight: Appearance.font.weightSemi
                    renderType: Text.NativeRendering
                }
            }
        }
    }

    // ACTIVE, in the strip rather than over it: the same height as the strip,
    // anchored off the clock, clear of both it and the workspaces -- which
    // give it the room by showing fewer slots.
    SlantBlock {
        id: activeBadge

        anchors.right: clock.left
        anchors.rightMargin: 6
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        visible: root.active
        // **The slant eats the right-hand end of the block**, so the label is
        // centred in what is left rather than in the whole rectangle and the
        // block is that much wider. At the real bar's 44 px the default 14 px
        // slant is a detail; on a 22 px strip it would be most of the badge.
        slant: 9
        width: activeTag.implicitWidth + 14 + slant
        fillColor: root.palette.accent

        NrLabel {
            id: activeTag

            anchors.fill: parent
            anchors.rightMargin: activeBadge.slant
            centred: true
            horizontalAlignment: Text.AlignHCenter
            color: root.palette.ground
            pixelSize: 11
            text: "ACTIVE"
        }
    }

    // **14 px from the right edge, not 22.** The old figure cleared the card's
    // whole 16 px chamfer; the cut is a diagonal, and what the clock has to
    // clear is where that diagonal is **at the clock's own top row**, which is
    // 12 px in. Measured against the mask rather than assumed from the depth.
    Text {
        id: clock

        anchors.right: parent.right
        anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter

        text: Qt.formatDateTime(new Date(), "HH:mm")
        color: root.palette.bright
        font.family: Appearance.font.display
        font.pixelSize: 12
        font.weight: Appearance.font.weightBold
        renderType: Text.NativeRendering
    }

    // The bar's accent line, running under the lit slot and no further --
    // **measured to the slot, not a fraction of the strip.** It was
    // `width * 0.32`, which was a guess that happened to look right before the
    // strip had workspace slots in it; the real bar's line ends at the right
    // edge of the lit one, and so does this.
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: spaces.fits > 0 ? spaces.x + spaces.slotWidth : pips.x + pips.width
        height: 1
        color: root.palette.accent
    }
}
