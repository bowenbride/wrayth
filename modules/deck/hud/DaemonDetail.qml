import QtQuick
import qs.components
import qs.components.ui as UI
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
        color: root.reading ? Daemons.toneColor(root.reading.tone) : Tokens.color.mute
        font.family: Tokens.font.display
        font.pixelSize: 22
        font.weight: Tokens.font.displayWeight
        elide: Text.ElideRight
    }

    // --- The plain-English explanation ---------------------------------------
    NrLabel {
        width: parent.width
        color: Tokens.color.mute
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
                    color: Tokens.color.dim
                    text: figure.pair ? figure.modelData.label : ""
                }

                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: figure.pair
                    renderType: Text.NativeRendering
                    text: figure.pair ? figure.modelData.value : ""
                    color: Tokens.color.text
                    font.family: Tokens.font.data
                    font.pixelSize: Appearance.size.body
                    font.weight: Tokens.font.dataWeight
                }

                // A sentence of context.
                NrLabel {
                    id: proseText

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !figure.pair
                    color: Tokens.color.mute
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
                    fillColor: chip.current ? Theme.alpha(Tokens.color.accent, 0.18)
                        : chipHover.hovered ? Theme.alpha(Tokens.color.hair, 0.4) : "transparent"
                    borderColor: chip.current ? Tokens.color.accent : Tokens.color.hair

                    Behavior on fillColor {
                        ColorAnimation {
                            duration: Tokens.motion.feedback
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.motion.easeIn
                        }
                    }

                    Behavior on borderColor {
                        ColorAnimation {
                            duration: Tokens.motion.feedback
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.motion.easeIn
                        }
                    }
                }

                NrLabel {
                    id: chipLabel

                    anchors.centerIn: parent
                    centred: true
                    color: chip.current ? Tokens.color.accent : chipHover.hovered ? Tokens.color.text : Tokens.color.dim
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

    // --- WEATHER: the city, the unit, the next hours, the ticker ------------------
    Column {
        width: parent.width
        spacing: 10
        visible: root.entry.id === "weather"

        Row {
            spacing: 8
            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                color: Tokens.color.dim
                text: "CITY"
            }
            InputField {
                id: cityField
                anchors.verticalCenter: parent.verticalCenter
                width: 180
                pixelSize: 11
                placeholder: "Type a city, then Enter"
                text: Weather.city
                onAccepted: Weather.setCity(text)
            }
            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                color: Weather.error !== "" ? Tokens.color.alert : Tokens.color.dim
                text: Weather.busy ? "LOOKING UP" : Weather.error
            }
        }

        // The unit as Chips; the ticker entry as a Toggle.
        Row {
            spacing: Tokens.space.s6
            UI.Label {
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                text: "UNIT"
            }
            Repeater {
                model: [["c", "°C"], ["f", "°F"]]
                UI.Chip {
                    required property var modelData
                    anchors.verticalCenter: parent.verticalCenter
                    text: modelData[1]
                    selected: Weather.unit === modelData[0]
                    onClicked: Weather.setUnit(modelData[0])
                }
            }
        }
        Row {
            spacing: Tokens.space.s6
            UI.Label {
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                text: "TICKER"
            }
            UI.Toggle {
                anchors.verticalCenter: parent.verticalCenter
                on: Weather.ticker
                onToggled: Weather.setTicker(!Weather.ticker)
            }
        }

        // The next hours: time, temperature, condition.
        Flow {
            width: parent.width
            spacing: 4
            Repeater {
                model: Weather.hours
                Column {
                    required property var modelData
                    width: 58
                    spacing: 2
                    NrLabel {
                        color: Tokens.color.dim
                        pixelSize: 9
                        text: modelData.time
                    }
                    NrLabel {
                        color: Tokens.color.bright
                        text: Weather.temp(modelData.temp)
                    }
                    NrLabel {
                        width: parent.width
                        elide: Text.ElideRight
                        color: Tokens.color.signal
                        pixelSize: 8
                        text: Weather.condition(modelData.code)
                    }
                }
            }
        }
    }
}
