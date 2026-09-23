import QtQuick
import qs.components
import qs.config
import qs.services

// The mirrored spectrum: each bar grows up and down from a hairline centre.
// Every bar stays the `signal` colour at every height -- the bar's height is
// already the reading, and recolouring the tall ones made loud passages look
// like a warning rather than like music. With nothing playing the bars fall to
// the centre line and it reads as a flat line.
Item {
    id: root

    property var values: []
    property int bars: Cava.bars

    // **What is drawn: instant on the way up, decaying on the way down.**
    // Every bar used to carry the same `Behavior on height` -- 110 ms in both
    // directions -- so however different the readings were, every bar climbed
    // and fell on one shared curve and the whole panel moved as a block. A
    // level meter should jump to a transient and then fall away. A `Behavior`
    // cannot express that, because it cannot see whether the new value is
    // above or below the old one, so the decay is computed here, once per cava
    // frame, and the bars themselves have no animation at all.
    //
    // It is done in the view rather than in `Cava`, so what the service
    // publishes stays the raw reading.
    property var shown: []
    // Fraction of full height lost per frame. At 60 fps a full-scale bar
    // reaches the centre line in about 8 frames.
    property real decay: 0.12

    onValuesChanged: {
        // **Nothing to recompute while nobody can see it.** cava stays up with
        // the deck down so the panel is live the instant it opens, but running
        // this decay 60 times a second against invisible bars measured a full
        // 1% of a core for no picture at all.
        if (!ShellState.deckVisible)
            return;
        if (!values || values.length === 0) {
            shown = [];
            return;
        }
        const next = [];
        for (let i = 0; i < root.bars; i++) {
            const v = values[i] ?? 0;
            const prev = shown[i] ?? 0;
            // Each bar decides for itself, against its own previous height.
            next.push(v >= prev ? v : Math.max(v, prev - root.decay));
        }
        shown = next;
    }
    // Bars collapse to nothing when silent; the flat line below takes over, so
    // silence reads as one unbroken rule rather than a row of dashes.
    property real minHeight: 0
    property bool live: Cava.live
    // MUTED animates in `alert` rather than falling flat: something is playing
    // that cannot be heard, and a flat line would say the opposite.
    readonly property color barColor: Audio.state === "MUTED" ? Theme.alert : Theme.signal

    readonly property real barWidth: Math.max(1, (width - (bars - 1) * spacing) / bars)
    property real spacing: 3

    // The axis the spectrum mirrors around, drawn under the bars so a bar reads
    // as one solid column rather than two halves with a slit between them.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Appearance.metrics.hairline
        color: Theme.hair
    }

    // What the spectrum falls to with nothing playing.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Appearance.metrics.hairline
        color: root.barColor
        opacity: root.live ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.duration.panel
                easing.type: Easing.OutCubic
            }
        }
    }

    // Arrive showing the reading as it is now. Picking up from whatever was on
    // screen when the deck last closed would decay a stale frame into place,
    // which is the freeze this whole change is about.
    Connections {
        target: ShellState

        function onDeckVisibleChanged(): void {
            if (ShellState.deckVisible)
                root.shown = (root.values ?? []).slice();
        }
    }

    Row {
        anchors.fill: parent
        spacing: root.spacing

        Repeater {
            model: root.bars

            Item {
                id: column

                required property int index

                readonly property real level: root.shown[index] ?? 0
                // Half the panel each way, mirrored around the centre.
                readonly property real arm: Math.max(root.minHeight, level * root.height / 2)

                width: root.barWidth
                height: root.height

                Rectangle {
                    id: upper

                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width
                    height: column.arm
                    color: root.barColor

                    // Pinned to the centre line by its own height, so the
                    // bottom edge cannot drift off the axis.
                    y: parent.height / 2 - height
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height / 2
                    width: parent.width
                    height: upper.height
                    color: upper.color
                }
            }
        }
    }

}
