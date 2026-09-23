import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services

// The top bar: full width, 44px, exclusive at the top of every screen.
Variants {
    model: ShellState.screens

    PanelWindow {
        id: bar

        required property ShellScreen modelData

        readonly property real edge: 12
        // The gap between the bar's structural groups.
        readonly property int groupGap: 14
        // The page marker and the workspace slots are one control -- the pager
        // and the page it is showing -- so the gap between them is set to the
        // indicator's own rhythm rather than to the bar's: the last pip stands
        // off the `01` digits by about what separates `01` from `02`, which is
        // the 2 px slot spacing plus the padding either side of a two-digit
        // label inside its 34 px slot. Measured to the slot's edge, not to the
        // digits, so it reads smaller than `groupGap` and is not.
        readonly property int markerGap: 10

        screen: modelData
        color: "transparent"
        implicitHeight: Appearance.metrics.barHeight

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "wrayth-bar"

        anchors {
            top: true
            left: true
            right: true
        }

        // The dropdown layer positions itself against this window and keeps it
        // inside its focus grab, so it has to be reachable from there.
        Component.onCompleted: ShellState.barWindow = bar

        // Reported to the dropdown layer, which holds its focus grab back while
        // the pointer is still up here. A handler rather than a MouseArea: it
        // sees the whole bar whatever the pointer is actually over.
        HoverHandler {
            onHoveredChanged: ShellState.barHovered = hovered
        }

        // Keep Awake holds a Wayland idle inhibitor against this surface, which
        // is what stops hypridle's timers from firing.
        // An inhibitor enabled before the bar's Wayland surface exists attaches
        // to nothing and never retries -- measured against hypridle, which
        // idled straight through it. **Now that HOLD is persisted this is the
        // normal path, not the corner case**: a shell that starts with HOLD
        // saved enables the inhibitor during construction, which is exactly
        // when the surface does not exist yet.
        property bool inhibitReady: false

        Timer {
            interval: 1000
            running: true
            onTriggered: bar.inhibitReady = true
        }

        IdleInhibitor {
            window: bar
            enabled: Idle.hold && bar.inhibitReady
        }

        Rectangle {
            anchors.fill: parent
            color: Theme.barBg
        }

        // Clicking bare bar dismisses an open dropdown. The bar sits inside the
        // dropdown's focus grab, so nothing else does it. Readouts tap through
        // to this on their way past, so it only fires when the stamp did not
        // move between press and release — i.e. when no readout claimed the tap.
        MouseArea {
            id: dismiss

            property int stamp: 0

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton

            onPressed: stamp = ShellState.dropdownStamp
            onClicked: {
                if (ShellState.dropdownStamp === stamp)
                    ShellState.dropdown = "";
            }
        }

        // 1px hair bottom border.
        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: Appearance.metrics.hairline
            color: Theme.hair
        }

        // --- The bar's bottom line -----------------------------------------
        // One unbroken accent run from the screen's left edge, under the ID
        // block and the stripes, to the **right edge of the active workspace's
        // slot**; from there a dim hair rail carries on to the end of the
        // indicator. One line the whole way across, so nothing doubles up --
        // the workspace slots draw no underline of their own.
        //
        // **Every figure in it is the real geometry of an element** -- the
        // block's measured width, the row's own position, the slot pitch --
        // never a number taken from one measurement. The block's contents now
        // change width every time a gig is ticked, so a constant would be
        // wrong the first time the count reached ten.
        // **The wrapper's x, not the workspaces' own.** `Workspaces` sits
        // inside a `GlitchFx` now, so its `x` is zero within that wrapper and
        // this measured from the row's left edge -- the line stopped about
        // 50 px short, just before the lit slot rather than at its far edge.
        // This is the trap the note above warns about, sprung by a wrapper
        // rather than by a constant.
        readonly property real workspacesLeft: left.x + workspacesFx.x
        readonly property real slotPitch: workspaces.itemWidth + workspaces.itemSpacing
        readonly property real indicatorEnd: workspacesLeft + workspaces.width

        // Where the accent stops. A slot is lit on every page -- numbered or
        // special -- so the fallback only fires in the moment between Hyprland
        // destroying a workspace and naming the next one, and it falls back to
        // the end of the stripes rather than collapsing to nothing.
        readonly property real accentEnd: workspaces.activeIndex >= 0 ? workspacesLeft + workspaces.activeIndex * slotPitch + workspaces.itemWidth : logo.width + bar.groupGap + stripes.width

        Item {
            id: line

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            width: bar.accentEnd
            height: 2

            // The line grows or retracts to the new slot rather than jumping.
            Behavior on width {
                NumberAnimation {
                    duration: Appearance.duration.move
                    easing.type: Easing.OutCubic
                }
            }

            Rectangle {
                id: accentLine

                anchors.fill: parent
                color: Theme.accent
            }

        }

        // The rail picks up wherever the accent stopped and runs to the end of
        // the indicator, so the two together are always exactly one line.
        Rectangle {
            id: rail

            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.leftMargin: line.width
            width: Math.max(0, bar.indicatorEnd - line.width)
            height: Appearance.metrics.hairline
            color: Theme.hair
        }

        // --- Left ----------------------------------------------------------
        // The logo block is structural, so it is anchored to the window itself
        // rather than sitting in the row: hard against the screen's left edge
        // and the top, running down to the bar's bottom border. It is declared
        // after the accent line so the two overlap in the same accent and read
        // as one shape rather than a block with a line starting beside it.
        // **The ID block is a glitch target, and the one an applied profile
        // fires.** It is the runner's name rather than a figure, so it may
        // scramble: `BO//01` is not something anybody acts on the value of.
        GlitchFx {
            group: "bar"
            id: logoFx

            key: "id"
            textual: true
            fills: true
            anchors.left: parent.left
            anchors.top: parent.top
            width: logo.implicitWidth
            height: logo.implicitHeight

            Logo {
                id: logo

                anchors.fill: parent
            }

            // A profile landing is the shell repainting itself, and the block
            // is where the shell says whose it is.
            Connections {
                target: Theme

                function onActiveProfileChanged(): void {
                    Glitch.fire("id", null);
                }
            }
        }

        // The bar's left section: logo, `groupGap`, page marker, `markerGap`,
        // workspaces. The marker is bound tight to the slots it pages through;
        // the full gap is kept for the boundary with the logo.
        Row {
            id: left

            anchors.left: logoFx.right
            anchors.leftMargin: bar.groupGap
            anchors.verticalCenter: parent.verticalCenter
            spacing: bar.markerGap

            // Replaces the hazard stripes: same slot, and the accent line
            // still runs underneath it.
            PageMarker {
                id: stripes

                anchors.verticalCenter: parent.verticalCenter
            }

            // Numbers: they may split and slice, never scramble.
            GlitchFx {
                group: "bar"
                id: workspacesFx

                fills: true

                anchors.verticalCenter: parent.verticalCenter
                width: workspaces.implicitWidth
                height: workspaces.implicitHeight
                numeric: true

                Workspaces {
                    id: workspaces

                    anchors.fill: parent
                }
            }
        }

        // --- Right ---------------------------------------------------------
        StatusItems {
            id: right

            anchors.right: parent.right
            anchors.rightMargin: bar.edge
            anchors.verticalCenter: parent.verticalCenter
        }

        // --- Centre --------------------------------------------------------
        // The ticker is the only flexible element on the bar: it spans whatever
        // the two fixed side groups leave and absorbs any change in their width.
        //
        // Its outer margins are the divider gap as well, not a wider group gap.
        // On the left that is the rule itself: the block opens with a hairline,
        // and a hairline stands off its neighbour by the same amount everywhere
        // on the bar. On the right the block ends in the katakana rather than a
        // rule, and takes the same inset so the centre sits evenly between the
        // two side groups.
        // Split and slice only. The ticker carries headlines -- body text by
        // any other name -- so its characters are never scrambled.
        GlitchFx {
            group: "bar"
            fills: true

            anchors.left: left.right
            anchors.right: right.left
            anchors.leftMargin: Appearance.metrics.dividerGap
            anchors.rightMargin: Appearance.metrics.dividerGap
            anchors.top: parent.top
            anchors.bottom: parent.bottom

            BarTicker {
                anchors.fill: parent
            }
        }

        // **Last, so it is over everything the bar draws**, and outside the
        // row so it covers the ID block and the accent line too. The bar is a
        // rectangle, so unlike a panel it needs no mask.
        Scanlines {
            surface: "panel"
        }
    }
}
