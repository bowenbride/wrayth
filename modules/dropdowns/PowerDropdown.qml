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

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: tile.modelData.katakana
                            color: Theme.signal
                            font.family: Appearance.font.accent
                            font.pixelSize: Appearance.size.katakana
                            font.weight: Appearance.font.weightMedium
                            renderType: Text.NativeRendering
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
    }
}
