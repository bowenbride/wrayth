import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.components
import qs.config
import qs.services

// Five slots, never more, never fewer, never a different width. What is in them
// is `MonitorSpaces`' business, for this bar's monitor: the page of numbered workspaces holding the active one,
// or the special workspaces while one of those is up.
Row {
    id: root

    // The bar draws the line under these, so it needs their pitch and which one
    // is lit. -1 leaves the line short rather than guessing.
    readonly property int itemWidth: Appearance.metrics.workspaceWidth
    readonly property int itemSpacing: 2
    readonly property int activeIndex: spaces.activeIndex

    // This bar's own monitor's workspaces, not the focused monitor's.
    readonly property MonitorSpaces spaces: MonitorSpaces {
        monitor: Hyprland.monitorFor(root.QsWindow.window?.screen ?? null)
    }

    spacing: itemSpacing

    Repeater {
        model: root.spaces.slots

        Item {
            id: button

            required property var modelData
            readonly property bool active: modelData.active

            width: Appearance.metrics.workspaceWidth
            height: Appearance.metrics.workspaceHeight

            Rectangle {
                anchors.fill: parent
                color: button.active ? Theme.alpha(Tokens.color.accent, 0.15) : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Tokens.motion.feedback
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.motion.easeIn
                    }
                }
            }

            // **`NrLabel`, so the number is centred on its ink.** It was a
            // bare `Text` centred as an item, which is off in both directions
            // at once: the tracking is added after the last digit as well, and
            // the item is as tall as the font's whole line while a digit draws
            // in the top two thirds of it. The spec calls this slot out by
            // name -- "the active workspace number worst of all".
            NrLabel {
                // A four-letter special label does not fit a slot sized for two
                // digits at the full label size, and the slot width is fixed.
                // The type shrinks; the slot does not. Held in its own property
                // rather than read back out of `font`, which is a binding loop.
                readonly property int size: button.modelData.label.length > 2 ? Appearance.size.workspaceSpecial : Appearance.size.workspace

                anchors.centerIn: parent
                centred: true

                text: button.modelData.label
                color: button.active ? Tokens.color.accent : Tokens.color.dim
                pixelSize: size
                font.features: Appearance.tabularFigures

                Behavior on color {
                    ColorAnimation {
                        duration: Tokens.motion.feedback
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.motion.easeIn
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                enabled: !button.modelData.empty
                cursorShape: Qt.PointingHandCursor

                // **No press flash here.** The shared flash exists to say a
                // click landed before the work starts, but a workspace switch
                // lands in a frame or two and lights this very slot -- so the
                // flash fired and faded on top of the highlight arriving, and
                // read as a blink rather than as an acknowledgement. The slot
                // taking the accent and the bar's line sliding to it are the
                // confirmation, and they are already animated.
                onClicked: Spaces.activate(button.modelData)
            }
        }
    }
}
