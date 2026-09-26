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

    // --- WEATHER: the city, the unit, the next hours, the ticker ------------------
    Column {
        width: parent.width
        spacing: 10
        visible: root.entry.id === "weather"

        Row {
            spacing: 8
            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.dim
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
                color: Weather.error !== "" ? Theme.alert : Theme.dim
                text: Weather.busy ? "LOOKING UP" : Weather.error
            }
        }

        Row {
            spacing: 6
            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                width: 48
                color: Theme.dim
                text: "UNIT"
            }
            Repeater {
                model: [["c", "°C"], ["f", "°F"], ["ticker", "TICKER"]]
                Rectangle {
                    id: wchip
                    required property var modelData
                    readonly property bool on: modelData[0] === "ticker" ? Weather.ticker : Weather.unit === modelData[0]
                    width: wLabel.implicitWidth + 16
                    height: 20
                    color: on ? Theme.alpha(Theme.accent, 0.18) : "transparent"
                    border.width: 1
                    border.color: on ? Theme.accent : Theme.hair
                    NrLabel {
                        id: wLabel
                        anchors.centerIn: parent
                        centred: true
                        color: wchip.on ? Theme.accent : Theme.text
                        text: wchip.modelData[1]
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: wchip.modelData[0] === "ticker" ? Weather.setTicker(!Weather.ticker) : Weather.setUnit(wchip.modelData[0])
                    }
                }
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
                        color: Theme.dim
                        pixelSize: 9
                        text: modelData.time
                    }
                    NrLabel {
                        color: Theme.bright
                        text: Weather.temp(modelData.temp)
                    }
                    NrLabel {
                        width: parent.width
                        elide: Text.ElideRight
                        color: Theme.signal
                        pixelSize: 8
                        text: Weather.condition(modelData.code)
                    }
                }
            }
        }
    }
}
