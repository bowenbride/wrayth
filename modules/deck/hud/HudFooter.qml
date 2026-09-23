import QtQuick
import qs.components
import qs.config
import qs.services
import qs.utils

// ICE, uptime, the package barcode and the kernel, pinned to the bottom of the
// HUD so the sections above can breathe.
Column {
    id: root

    spacing: 8

    // --- ICE and uptime ----------------------------------------------------
    Item {
        width: parent.width
        height: 14

        // **ICE is an event target.** It changing state is the shell finding
        // something out rather than the user doing something, which is exactly
        // when a glitch means something. SHIELD fires the same key: they are
        // the two lines on this footer that report a system's health, and only
        // one of them can be glitching at a time anyway.
        GlitchFx {
            group: "deck"
            id: iceFx

            key: "ice"
            fills: true
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: iceRow.implicitWidth
            height: iceRow.implicitHeight

        Row {
            id: iceRow

            anchors.fill: parent
            spacing: 7

            // A slow pulse, so a healthy system still looks alive.
            Rectangle {
                id: pulse

                anchors.verticalCenter: parent.verticalCenter
                width: 7
                height: 7
                color: SystemStatus.breach ? Theme.accent : Theme.signal

                // **Only while anybody can see it.** An infinite animation
                // on a panel whose window is unmapped still ticks its
                // property sixty times a second, re-evaluates everything
                // bound to it, and keeps the scene dirty -- for a pulse
                // nobody is looking at. Every animated thing on the deck is
                // gated the same way.
                SequentialAnimation on opacity {
                    running: ShellState.deckVisible
                    loops: Animation.Infinite

                    NumberAnimation {
                        to: 0.25
                        duration: 900
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 1
                        duration: 900
                        easing.type: Easing.InOutSine
                    }
                }
            }

            Text {
                renderType: Text.NativeRendering
                anchors.verticalCenter: parent.verticalCenter

                text: SystemStatus.breach ? `ICE${Appearance.separator}BREACH` : `ICE${Appearance.separator}NOMINAL`
                color: SystemStatus.breach ? Theme.accent : Theme.text
                font.family: Appearance.font.data
                font.pixelSize: Appearance.size.label
                font.weight: Appearance.font.weightSemi
                font.letterSpacing: Appearance.tracking(Appearance.size.label)
                font.capitalization: Font.AllUppercase
            }

            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                text: `${SystemStatus.failedUnits} FAILED`
            }
        }

            // ICE turning over, and SHIELD with it. Both are the shell
            // finding something out rather than the user doing something,
            // which is exactly when a glitch carries meaning.
            Connections {
                target: SystemStatus

                function onBreachChanged(): void {
                    Glitch.fire("ice", null);
                }

                function onShieldArmedChanged(): void {
                    Glitch.fire("ice", null);
                }
            }
        }

        NrLabel {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: `UPTIME ${Fmt.duration(SysInfo.uptimeSeconds)}`
        }
    }

    // --- Packages ----------------------------------------------------------
    Item {
        width: parent.width
        height: 14

        Barcode {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            height: 11
            count: SystemStatus.pendingUpdates
        }

        NrLabel {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: `PKG${Appearance.separator}${SystemStatus.pendingUpdates} PENDING`
        }
    }

    NrLabel {
        width: parent.width
        horizontalAlignment: Text.AlignRight
        // Set apart from the package line: it belongs to the machine, not to
        // anything being measured.
        topPadding: 10
        color: Theme.mute
        // A version string, not a label.
        font.capitalization: Font.MixedCase
        text: `KRN ${Machine.kernel}`
    }
}
