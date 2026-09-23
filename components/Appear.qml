import QtQuick
import qs.config

// Anything that comes and goes. **Nothing in the shell appears or disappears
// without going through this, or without doing exactly what this does.**
//
//   appearing -- fade in with an 8 px rise, 250 ms, ease-out.
//   leaving   -- fade out over 180 ms, ease-in, and only then release its
//                space.
//
// The two halves are not symmetrical on purpose. Something arriving has to be
// noticed, so it travels; something leaving has nothing left to say, so it
// only fades, and it goes quicker. **The space is released last**, after the
// fade has finished, because a positioner closing the gap while the item is
// still drawing in it is the jump this exists to stop.
//
// The rise is a **transform**. It moves the painted content and changes
// nothing about the item's size or where its neighbours sit: an animation in
// this shell never re-lays anything out.
//
// A section animates as **one object** -- one opacity on the container, never
// one child after another. Staggering between sibling panels is allowed and is
// the deck's business; staggering between children of one panel is not.
Item {
    id: root

    property bool shown: false
    // Set when the host gives this explicit dimensions or anchors, so the
    // implicit size is not derived from the content and nothing fights over
    // who decides the width.
    property bool fills: false

    default property alias content: holder.data

    implicitWidth: fills ? 0 : holder.childrenRect.width
    implicitHeight: fills ? 0 : holder.childrenRect.height

    opacity: shown ? 1 : 0
    // The space goes when the fade is over, not when the decision is made.
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: root.shown ? Appearance.duration.enter : Appearance.duration.exit
            easing.type: root.shown ? Easing.OutCubic : Easing.InCubic
        }
    }

    // --- The rise ------------------------------------------------------------
    property real rise: Appearance.enterRise
    // Nothing animates until the first frame has been laid out, or an item
    // that is shown from the start slides up on every config reload.
    property bool ready: false

    Behavior on rise {
        // Reset silently while hidden: the offset is put back for next time
        // the moment the item stops being drawn, and animating that would be
        // animating something nobody can see.
        enabled: root.ready && root.visible

        NumberAnimation {
            duration: Appearance.duration.enter
            easing.type: Easing.OutCubic
        }
    }

    onShownChanged: if (shown) rise = 0
    onVisibleChanged: if (!visible) rise = Appearance.enterRise

    Component.onCompleted: {
        rise = shown ? 0 : Appearance.enterRise;
        ready = true;
    }

    transform: Translate {
        y: root.rise
    }

    Item {
        id: holder

        anchors.fill: parent
    }
}
