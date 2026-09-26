import QtQuick
import qs.components
import qs.config
import qs.services
import qs.utils

DropdownFrame {
    id: root

    // Which profile is being applied, so only that tile wears the state.
    property string applying: ""

    ActionState {
        id: applyAction
    }

    Connections {
        target: Power

        function onProfileChanged(): void {
            if (applyAction.working)
                applyAction.succeed();
        }
    }

    // Anything "not installed" is asked again as the dropdown opens.
    Component.onCompleted: NightLight.recheck()

    title: "PWR // PROFILE"
    katakana: "電力"

    headerRight: NrLabel {
        text: `${Power.onBattery ? "BATTERY" : "AC"} // ${Power.stateLabel()}`
        color: Theme.text
    }

    Column {
        width: parent.width
        // The frame's own padding. See the note in the Wi-Fi dropdown.
        spacing: root.padding

        // --- Charge --------------------------------------------------------
        Item {
            width: parent.width
            height: 46

            TabularText {
                id: charge

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter

                text: Power.present ? `${Math.round(Power.charge)}%` : "--"
                color: Theme.bright
                font.family: Appearance.font.display
                font.pixelSize: 38
                font.weight: Appearance.font.weightBold
            }

            NrLabel {
                anchors.left: charge.right
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                text: `BATTERY // ${Power.stateLabel()}`
            }
        }

        // 20-segment battery bar.
        SegmentMeter {
            width: parent.width
            segments: 20
            segmentWidth: (parent.width - 19 * 2) / 20
            segmentHeight: 8
            value: Power.charge / 100
            litColor: Theme.signal
        }

        // --- Profile tiles -------------------------------------------------
        Row {
            width: parent.width
            spacing: 8

            Repeater {
                model: Power.profiles

                Rectangle {
                    id: tile

                    required property var modelData
                    readonly property bool selected: Power.profile === modelData.id
                    readonly property bool available: modelData.label !== "PERFORMANCE" || Power.hasPerformance

                    width: (parent.width - 16) / 3
                    height: 52
                    opacity: available ? 1 : 0.4

                    color: selected ? Theme.alpha(Theme.accent, 0.12) : "transparent"
                    border.width: Appearance.metrics.hairline
                    border.color: selected ? Theme.accent : Theme.hair

                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.duration.state
                            easing.type: Easing.OutCubic
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: Appearance.duration.state
                            easing.type: Easing.OutCubic
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: 4

                        Text {
                            renderType: Text.NativeRendering
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.label
                            color: tile.selected ? Theme.accent : Theme.text
                            font.family: Appearance.font.data
                            font.pixelSize: Appearance.size.label
                            font.weight: Appearance.font.weightSemi
                            font.letterSpacing: Appearance.tracking(Appearance.size.label)
                            font.capitalization: Font.AllUppercase
                        }

                        KanaTag {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.katakana
                        }
                    }

                    // APPLYING until power-profiles-daemon reports the new
                    // profile back over D-Bus, rather than until the command
                    // has been sent -- the daemon is what decides.
                    Feedback {
                        id: tileFeedback

                        anchors.fill: parent
                        working: applyAction.working && root.applying === tile.modelData.cli
                        succeeded: applyAction.succeeded && root.applying === tile.modelData.cli
                    }

                    WorkSegments {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 8
                        running: tileFeedback.working
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: tile.available && !applyAction.working
                        cursorShape: Qt.PointingHandCursor

                        onPressed: tileFeedback.flash()
                        onClicked: tileDefer.restart()
                    }

                    Timer {
                        id: tileDefer

                        interval: 16
                        onTriggered: {
                            root.applying = tile.modelData.cli;
                            applyAction.begin("APPLYING");
                            Power.setProfile(tile.modelData.cli);
                        }
                    }
                }
            }
        }
            // --- NIGHT LIGHT -----------------------------------------------------
        Rectangle {
            width: parent.width
            height: Appearance.metrics.hairline
            color: Theme.hair
        }

        Column {
            id: night

            width: parent.width
            spacing: 10

            // A warm gradient across the segments: the colour of the light
            // each step gives, from near-white to deep amber.
            function warm(i: int): color {
                const t = i / 19;
                return Qt.rgba(1, 0.92 - 0.38 * t, 0.78 - 0.62 * t, 1);
            }

            Item {
                width: parent.width
                height: 22

                Text {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "NIGHT LIGHT"
                    color: Theme.bright
                    font.family: Appearance.font.data
                    font.pixelSize: 12
                    font.weight: Appearance.font.weightSemi
                    font.letterSpacing: 12 * 0.14
                    renderType: Text.NativeRendering
                }
                Text {
                    anchors.right: nightToggle.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !NightLight.available
                    text: "HYPRSUNSET NOT INSTALLED"
                    color: Theme.dim
                    font.family: Appearance.font.data
                    font.pixelSize: 9
                    font.letterSpacing: 9 * 0.12
                    renderType: Text.NativeRendering
                }
                ToggleButton {
                    id: nightToggle

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 58
                    height: 22
                    on: NightLight.on
                    onToggled: NightLight.setOn(!NightLight.on)
                }
            }

            // WARMTH: 20 clickable segments and the temperature in kelvin.
            Item {
                width: parent.width
                height: 14

                Text {
                    id: warmthLabel

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 62
                    text: "WARMTH"
                    color: Theme.dim
                    font.family: Appearance.font.data
                    font.pixelSize: 9
                    font.letterSpacing: 9 * 0.12
                    renderType: Text.NativeRendering
                }
                Row {
                    id: warmthSegs

                    readonly property int lit: NightLight.segmentsOf(NightLight.kelvin)
                    readonly property real seg: (width - 19 * 2) / 20

                    anchors.left: warmthLabel.right
                    anchors.right: kelvinText.left
                    anchors.rightMargin: 6
                    anchors.verticalCenter: parent.verticalCenter
                    height: 12
                    spacing: 2

                    Repeater {
                        model: 20
                        Rectangle {
                            required property int index
                            width: warmthSegs.seg
                            height: 12
                            color: index < warmthSegs.lit ? night.warm(index) : Theme.track
                            opacity: NightLight.on ? 1 : 0.5
                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.duration.state
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    // Click or drag: the segment under the pointer and all
                    // before it.
                    function pick(x: real): void {
                        const n = Math.max(1, Math.min(20, Math.ceil(x / (seg + 2))));
                        NightLight.setKelvin(NightLight.kelvinOf(n));
                    }
                    TapHandler {
                        onTapped: e => warmthSegs.pick(e.position.x)
                    }
                    DragHandler {
                        target: null
                        xAxis.enabled: true
                        yAxis.enabled: false
                        onCentroidChanged: if (active) warmthSegs.pick(centroid.position.x)
                    }
                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }
                }
                Text {
                    id: kelvinText

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    horizontalAlignment: Text.AlignRight
                    text: `${NightLight.kelvin}K`
                    color: Theme.text
                    font.family: Appearance.font.data
                    font.pixelSize: 10
                    font.features: Appearance.tabularFigures
                    renderType: Text.NativeRendering
                }
            }

            // SCHEDULE: MANUAL or SET TIMES.
            Item {
                width: parent.width
                height: 22

                Text {
                    id: schedLabel

                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    width: 62
                    text: "SCHEDULE"
                    color: Theme.dim
                    font.family: Appearance.font.data
                    font.pixelSize: 9
                    font.letterSpacing: 9 * 0.12
                    renderType: Text.NativeRendering
                }
                Row {
                    anchors.left: schedLabel.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Repeater {
                        model: [["manual", "MANUAL"], ["times", "SET TIMES"]]

                        Rectangle {
                            id: chip

                            required property var modelData
                            readonly property bool selected: NightLight.schedule === modelData[0]

                            width: chipText.implicitWidth + 20
                            height: 22
                            color: selected ? Theme.alpha(Theme.accent, 0.12) : (chipHover.hovered ? Theme.cell : "transparent")
                            border.width: 1
                            border.color: selected ? Theme.accent : Theme.hair

                            Text {
                                id: chipText

                                anchors.centerIn: parent
                                text: chip.modelData[1]
                                color: chip.selected ? Theme.accent : Theme.text
                                font.family: Appearance.font.data
                                font.pixelSize: 9
                                font.weight: Appearance.font.weightSemi
                                font.letterSpacing: 9 * 0.12
                                renderType: Text.NativeRendering
                            }
                            HoverHandler {
                                id: chipHover
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: NightLight.setSchedule(chip.modelData[0])
                            }
                        }
                    }
                }
            }

            // FROM and TO, HH:MM, only with SET TIMES. A time that is not a
            // real one is not kept: the field turns the alert colour and the
            // saved time stays.
            Item {
                width: parent.width
                height: 24
                visible: NightLight.schedule === "times"

                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 62
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Repeater {
                        model: [["FROM", "from"], ["TO", "to"]]

                        Row {
                            id: field

                            required property var modelData
                            spacing: 6

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: field.modelData[0]
                                color: Theme.dim
                                font.family: Appearance.font.data
                                font.pixelSize: 9
                                font.letterSpacing: 9 * 0.12
                                renderType: Text.NativeRendering
                            }
                            InputField {
                                id: timeInput

                                property bool bad: false

                                width: 58
                                height: 24
                                maximumLength: 5
                                placeholder: "HH:MM"
                                text: NightLight[field.modelData[1]]
                                frameColor: bad ? Theme.alert : (editing ? Theme.accent : Theme.hair)
                                onEdited: v => bad = v.length === 5 && !NightLight.validTime(v)
                                onAccepted: commit()
                                onEditingChanged: if (!editing) commit()
                                function commit(): void {
                                    const v = text.trim();
                                    if (!NightLight.validTime(v)) {
                                        bad = v !== "";
                                        return;
                                    }
                                    bad = false;
                                    if (field.modelData[1] === "from")
                                        NightLight.setTimes(v, NightLight.to);
                                    else
                                        NightLight.setTimes(NightLight.from, v);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
