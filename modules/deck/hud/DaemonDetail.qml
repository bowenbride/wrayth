import QtQuick
import qs.components
import qs.config
import qs.services

// The open daemon's detail, filling the HUD from just under its name to the
// bottom. A one- or two-sentence plain-English explanation, the headline
// reading in its own tone, then the figures that matter -- one per row, label
// and value -- and, for PING, a latency sparkline and the selectable cities.
//
// The name itself is not here: the HUD lifts the row's name up to the label's
// place and this fills the space below it, so the two read as one panel.
Column {
    id: root

    required property var entry
    readonly property var reading: Daemons.readings[entry.id] ?? null
    readonly property bool isPing: entry.id === "ping"

    spacing: 10

    // --- The headline reading, in its tone -----------------------------------
    Text {
        id: headline

        width: parent.width
        renderType: Text.NativeRendering
        text: root.reading?.value ?? "..."
        color: root.reading ? Daemons.toneColor(root.reading.tone) : Theme.mute
        font.family: Appearance.font.display
        font.pixelSize: 22
        font.weight: Appearance.font.weightBold
        elide: Text.ElideRight
    }

    // --- The plain-English explanation ---------------------------------------
    NrLabel {
        width: parent.width
        color: Theme.mute
        wrapMode: Text.WordWrap
        font.capitalization: Font.MixedCase
        text: root.entry.description
    }

    // --- PING: a latency sparkline over the recent readings ------------------
    Sparkline {
        width: parent.width
        height: 40
        visible: root.isPing && Daemons.pingHistory.length > 1
        points: 24
        // Latencies are milliseconds, not bytes; floor low so the trace fills
        // the box instead of sitting flat against the default network floor.
        floorValue: 1
        downValues: Daemons.pingHistory
        upValues: []
    }

    // --- The figures, one per row --------------------------------------------
    Column {
        width: parent.width
        spacing: 4

        Repeater {
            // PING's TARGET row is dropped: the chips below name the target and
            // let it be changed, so the raw host would only repeat it.
            model: {
                const rows = root.reading?.rows ?? [];
                return root.isPing ? rows.filter(r => r.label !== "TARGET") : rows;
            }

            delegate: Item {
                id: figure

                required property var modelData
                readonly property bool pair: modelData.value !== undefined

                width: parent.width
                implicitHeight: pair ? 16 : proseText.implicitHeight + 2

                // A label / value figure.
                NrLabel {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    visible: figure.pair
                    color: Theme.dim
                    text: figure.pair ? figure.modelData.label : ""
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: figure.pair
                    renderType: Text.NativeRendering
                    text: figure.pair ? figure.modelData.value : ""
                    color: Theme.text
                    font.family: Appearance.font.data
                    font.pixelSize: Appearance.size.body
                    font.weight: Appearance.font.weightSemi
                }

                // A sentence of context.
                NrLabel {
                    id: proseText

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !figure.pair
                    color: Theme.mute
                    wrapMode: Text.WordWrap
                    font.capitalization: Font.MixedCase
                    text: figure.pair ? "" : figure.modelData.text
                }
            }
        }
    }

    // --- PING: the selectable cities -----------------------------------------
    Flow {
        width: parent.width
        spacing: 6
        visible: root.isPing

        Repeater {
            model: root.isPing ? Daemons.pingTargets : []

            delegate: Item {
                id: chip

                required property var modelData
                readonly property bool current: modelData.host === Daemons.pingTarget

                implicitWidth: chipLabel.implicitWidth + 16
                implicitHeight: 20

                ChamferPanel {
                    anchors.fill: parent
                    chamfer: 6
                    scanlines: false
                    fillColor: chip.current ? Theme.alpha(Theme.accent, 0.18)
                        : chipHover.hovered ? Theme.alpha(Theme.hair, 0.4) : "transparent"
                    borderColor: chip.current ? Theme.accent : Theme.hair

                    Behavior on fillColor {
                        ColorAnimation {
                            duration: Appearance.duration.state
                            easing.type: Easing.OutCubic
                        }
                    }

                    Behavior on borderColor {
                        ColorAnimation {
                            duration: Appearance.duration.state
                            easing.type: Easing.OutCubic
                        }
                    }
                }

                NrLabel {
                    id: chipLabel

                    anchors.centerIn: parent
                    centred: true
                    color: chip.current ? Theme.accent : chipHover.hovered ? Theme.text : Theme.dim
                    text: chip.modelData.name
                }

                HoverHandler {
                    id: chipHover
                    cursorShape: Qt.PointingHandCursor
                }

                Feedback {
                    id: chipFeedback
                    anchors.fill: parent
                    flashOpacity: 0.2
                }

                TapHandler {
                    onPressedChanged: if (pressed) chipFeedback.flash()
                    onTapped: Daemons.setPingTarget(chip.modelData.host)
                }
            }
        }
    }
}
