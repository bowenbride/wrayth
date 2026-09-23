import QtQuick
import qs.components
import qs.config

// The planner's 18x18 tick button. Three looks: the active task wears the
// accent, a finished one is filled `mute` with a tick, the rest are a hairline.
Item {
    id: root

    property bool checked: false
    property bool active: false

    signal toggled

    implicitWidth: 18
    implicitHeight: 18

    Rectangle {
        anchors.fill: parent

        color: {
            if (root.checked)
                return Theme.mute;
            if (root.active)
                return Theme.alpha(Theme.accent, 0.15);
            return "transparent";
        }
        border.width: Appearance.metrics.hairline
        border.color: root.active && !root.checked ? Theme.accent : Theme.hair

        Behavior on color {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }
    }

    // **`Glyph`, not a bare `Text`.** A `Text` item is as tall as the font's
    // whole line whatever the character draws, so a lone tick centred as an
    // item sits low and left inside an 18 px box. `Glyph` centres the measured
    // ink -- the same rule the pool chips' tick already followed.
    Glyph {
        anchors.centerIn: parent
        // The tick is the control changing state, not an element arriving:
        // 120 ms, no rise.
        visible: opacity > 0
        opacity: root.checked ? 1 : 0
        text: "✓"
        color: Theme.ground
        pixelSize: 12
        weight: Appearance.font.weightBold

        Behavior on opacity {
            NumberAnimation {
                duration: Appearance.duration.state
                easing.type: root.checked ? Easing.OutCubic : Easing.InCubic
            }
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    Feedback {
        id: feedback

        anchors.fill: parent
        flashOpacity: 0.35
    }

    TapHandler {
        // Instant: the tick itself is the feedback, the flash only confirms
        // that the click landed on the box rather than the row.
        onPressedChanged: if (pressed) feedback.flash()
        onTapped: root.toggled()
    }
}
