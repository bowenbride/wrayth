import QtQuick
import qs.components
import qs.config
import qs.services

// One wallpaper in one profile's pool. Three controls, because it carries
// three separate ideas and they are not the same question:
//
//   the tickbox  -- in the rotation. An unticked chip stays in the pool,
//                   faded, and is skipped.
//   the CARD tag -- this is the image the picker shows for this profile.
//                   Exactly one per profile. Solid on the chosen chip; an
//                   outline on the others, and only while the pointer or the
//                   keyboard is on them.
//   the minus    -- out of this profile's pool. **Never deletes the file**,
//                   which is why it is a quiet mark that is not even on
//                   screen at rest, where the library's DELETE is a word in
//                   `alert` that always is.
Item {
    id: root

    required property var item
    required property bool starred
    // The row's profile, so the tag is in that profile's colours rather than
    // in whatever the shell is wearing.
    required property color tone
    required property color ink
    // The keyboard's position in the pools screen. The pointer is not the only
    // way to reach a chip.
    property bool focused: false

    readonly property bool revealed: hover.hovered || root.focused

    signal toggled
    signal starRequested
    signal removeRequested
    signal dragStarted(var payload, real x, real y)
    signal dragMoved(real x, real y)
    signal dragEnded

    implicitWidth: 108
    implicitHeight: 60

    HoverHandler {
        id: hover
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.deep
        border.width: Appearance.metrics.hairline
        border.color: root.starred ? root.tone : root.focused ? Theme.accent : Theme.hair

        Behavior on border.color {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }
    }

    Image {
        anchors.fill: parent
        anchors.margins: 1
        source: Wallpapers.imageOf(root.item.file)
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(220, 120)
        asynchronous: true
        cache: true
        // Faded rather than hidden: it is still in the pool, it is just not in
        // the rotation, and the difference has to be visible at a glance.
        opacity: root.item.on ? 1 : 0.32

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }
    }

    // --- Tickbox ---------------------------------------------------------
    // 18 px, not 13, and on an opaque backing. At 13 px over a photograph the
    // controls could not be told apart, let alone read.
    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 4
        width: 18
        height: 18
        color: root.item.on ? Theme.accent : Qt.rgba(0, 0, 0, 0.82)
        border.width: Appearance.metrics.hairline
        border.color: root.item.on ? Theme.accent : Theme.dim

        Glyph {
            anchors.centerIn: parent
            // A mark inside a control is the control changing state, not an
            // element arriving: it takes the 120 ms state feedback and no
            // rise. See the animation rules.
            visible: opacity > 0
            opacity: root.item.on ? 1 : 0
            text: "✓"

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.duration.state
                    easing.type: root.item.on ? Easing.OutCubic : Easing.InCubic
                }
            }
            color: Theme.ground
            pixelSize: 12
            weight: Appearance.font.weightBold
        }

        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.toggled()
        }
    }

    // --- CARD ------------------------------------------------------------
    // Top-right, and the only thing in the corner: the chosen chip wears it
    // solid, and an unchosen one offers it as an outline under the pointer.
    CardTag {
        id: card

        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 4

        tone: root.tone
        ink: root.ink
        chosen: root.starred
        hovered: cardHover.hovered
        // An outline on every chip at rest would say every chip was chosen.
        //
        // **`visible` follows the opacity, not the condition.** Bound to the
        // condition it went false on the first frame of the fade out, so the
        // tag vanished and the fade it was given never ran.
        visible: opacity > 0
        opacity: root.starred || root.revealed ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.duration.state
                easing.type: root.starred || root.revealed ? Easing.OutCubic : Easing.InCubic
            }
        }

        HoverHandler {
            id: cardHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            // A second press on the chip that already has it changes nothing;
            // it is not a toggle, because a profile always has a card image.
            enabled: !root.starred
            onTapped: root.starRequested()
        }
    }

    // --- Remove ------------------------------------------------------------
    // Quiet: no frame, no word, and not on screen until the pointer or the
    // keyboard is on the chip. Taking a wallpaper out of one profile is undone
    // by dragging it back, and a reversible action does not need a control
    // sitting on the image at rest.
    Item {
        id: minus

        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 4
        width: 18
        height: 18
        visible: opacity > 0
        opacity: root.revealed ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.duration.state
                easing.type: root.revealed ? Easing.OutCubic : Easing.InCubic
            }
        }

        Rectangle {
            anchors.fill: parent
            // Opaque, because it is over a photograph -- but no border, which
            // is the whole of what makes it quieter than the tag above it.
            color: Qt.rgba(0, 0, 0, minusHover.hovered ? 0.9 : 0.72)
        }

        MinusGlyph {
            anchors.fill: parent
            color: minusHover.hovered ? Theme.accent : Theme.dim

            Behavior on color {
                ColorAnimation {
                    duration: Appearance.duration.state
                    easing.type: Easing.OutCubic
                }
            }
        }

        HoverHandler {
            id: minusHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.removeRequested()
        }
    }

    MouseArea {
        anchors.fill: parent
        z: -1

        property bool dragging: false
        property point origin

        onPressed: mouse => {
            origin = Qt.point(mouse.x, mouse.y);
            dragging = false;
        }

        onPositionChanged: mouse => {
            if (!pressed)
                return;
            const moved = Math.abs(mouse.x - origin.x) + Math.abs(mouse.y - origin.y);
            const global = root.mapToItem(null, mouse.x, mouse.y);
            if (!dragging && moved > 6) {
                dragging = true;
                root.dragStarted(root.item.file, global.x, global.y);
            } else if (dragging) {
                root.dragMoved(global.x, global.y);
            }
        }

        onReleased: {
            if (dragging)
                root.dragEnded();
            dragging = false;
        }

        // A grab can be taken away -- the window losing focus, another handler
        // claiming it. Without this the ghost is stranded on screen and the
        // screen goes on believing something is in hand.
        onCanceled: {
            if (dragging)
                root.dragEnded();
            dragging = false;
        }
    }
}
