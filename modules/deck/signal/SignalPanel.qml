import QtQuick
import qs.components
import qs.config
import qs.services

// SIGNAL // AUDIO: the deck's spectrum, on the bottom row's line beside the
// planner and vuln watch.
ChamferPanel {
    id: root

    readonly property real padding: 14

    // The mirror of the HUD above it: cut top-left and bottom-right, with the
    // accent brackets on the two square corners. See the deck corner scheme.
    chamfer: Appearance.chamfer.panel
    chamferTopLeft: chamfer
    chamferTopRight: 0
    chamferBottomRight: chamfer
    chamferBottomLeft: 0
    fillColor: Theme.panel

    CornerBrackets {
        inset: 6
        corners: ["topRight", "bottomLeft"]
    }

    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.padding
        height: 18

        GlitchFx {
            group: "deck"
            key: "panel:signal"
            textual: true
            fills: true
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: signalHeaderRow.implicitWidth
            height: signalHeaderRow.implicitHeight
            scrambleItems: [signalTitle]

        Row {
            id: signalHeaderRow

            anchors.fill: parent
            spacing: 8

            NrLabel {
                id: signalTitle

                anchors.verticalCenter: parent.verticalCenter
                color: Theme.bright
                text: "SIGNAL"
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "信号"
                color: Theme.signal
                font.family: Appearance.font.accent
                font.pixelSize: Appearance.size.katakana
                font.weight: Appearance.font.weightMedium
                renderType: Text.NativeRendering
            }
        }
        }

        Row {
            id: device

            // This row ends in the panel's top-right corner, where the gap
            // above it and the gap beside it are seen against each other. The
            // header box is taller than the type, so the ink sits a little
            // lower than the 14 px padding, while on the right it clears only
            // the trailing letter-spacing -- which left the corner reading
            // tighter on the right than on the top.
            //
            // Measured on screen at the panel's own edges: 18 px above the
            // ink, 16 px beside it. This 2 px is the difference, and it is a
            // measurement rather than a derivation on purpose -- a formula off
            // FontMetrics and tightBoundingRect gives 3.7, because ideal ink
            // extents and where the rasteriser actually lays down antialiased
            // coverage are not the same thing. Re-measure it if the label size
            // or the header height changes.
            readonly property real cornerTrim: 2

            anchors.right: parent.right
            anchors.rightMargin: cornerTrim
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0

            NrLabel {
                id: name

                anchors.verticalCenter: parent.verticalCenter
                // Capped so a long device name truncates rather than running
                // into the panel title.
                width: Math.min(implicitWidth, header.width - 190)
                elide: Text.ElideRight
                text: Audio.deviceName
            }

            // The state, always shown: the device name alone cannot tell
            // STANDBY from OFFLINE, and MUTED is the one that most needs
            // saying out loud.
            Text {
                renderType: Text.NativeRendering
                id: live

                readonly property color tone: {
                    if (Audio.state === "LIVE")
                        return Theme.accent;
                    if (Audio.state === "MUTED")
                        return Theme.alert;
                    if (Audio.state === "STANDBY")
                        return Theme.text;
                    return Theme.dim;
                }

                anchors.verticalCenter: parent.verticalCenter

                text: Audio.state
                color: tone
                font.family: Appearance.font.data
                font.pixelSize: Appearance.size.label
                font.weight: Appearance.font.weightSemi
                font.letterSpacing: Appearance.tracking(Appearance.size.label)
                font.capitalization: Font.AllUppercase
            }
        }
    }

    // The visualiser splits and slices like anything else in the shell. It has
    // no text in it, so it never scrambles -- the flag is not even needed.
    GlitchFx {
        group: "deck"
        fills: true

        anchors.top: header.bottom
        anchors.topMargin: root.padding * 0.6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.bottomMargin: root.padding

        Spectrum {
            anchors.fill: parent

            values: Cava.levels
        }
    }
}
