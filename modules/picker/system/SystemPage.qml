import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.components
import qs.config
import qs.services

// SYSTEM: display, motion, game mode and idle, beside EFFECTS and PRIVACY.
// Two columns of sections, each row a 150 px label and chips; everything is
// saved and applied the moment a chip is pressed.
Item {
    id: root

    signal finished

    function back(): bool {
        return false;
    }

    readonly property int originX: 250
    readonly property int endX: 1710
    readonly property int span: endX - originX
    readonly property rect contentRect: Qt.rect(originX - 38, 90, span + 76, 700)

    // Screens whose scale is set one by one when they differ; one row when
    // there is one screen.
    readonly property var outputs: (Hyprland.monitors?.values ?? []).map(m => m.name)
    function scaleOf(output: string): real {
        return SystemSettings.scale[output] ?? (Hyprland.monitors?.values ?? []).find(m => m.name === output)?.lastIpcObject?.scale ?? 1;
    }

    component Section: Column {
        id: section

        property string title: ""
        default property alias rows: body.data

        width: 640
        spacing: 12

        Column {
            width: parent.width
            spacing: 6
            Text {
                text: section.title
                color: Theme.signal
                font.family: Appearance.font.data
                font.pixelSize: 11
                font.weight: Appearance.font.weightSemi
                font.letterSpacing: 11 * 0.14
                renderType: Text.NativeRendering
            }
            Rectangle {
                width: parent.width
                height: Appearance.metrics.hairline
                color: Theme.hair
            }
        }
        Column {
            id: body
            width: parent.width
            spacing: 10
        }
    }

    // A 150 px label and 24 px chips, the accent on the chosen one.
    component ChipRow: Row {
        id: chipRow

        property string label: ""
        property var options: []        // [[value, text]]
        property var current
        signal chosen(var value)

        spacing: 0
        Text {
            width: 150
            height: 24
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
            text: chipRow.label
            color: Theme.dim
            font.family: Appearance.font.data
            font.pixelSize: 10
            font.letterSpacing: 10 * 0.12
            renderType: Text.NativeRendering
        }
        Row {
            spacing: 6
            Repeater {
                model: chipRow.options
                Rectangle {
                    id: chip

                    required property var modelData
                    readonly property bool selected: chipRow.current === modelData[0]

                    width: chipText.implicitWidth + 20
                    height: 24
                    color: selected ? Theme.alpha(Theme.accent, 0.12) : (chipHover.hovered ? Theme.cell : "transparent")
                    border.width: 1
                    border.color: selected ? Theme.accent : Theme.hair
                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.duration.state
                            easing.type: Easing.OutCubic
                        }
                    }
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
                        onTapped: chipRow.chosen(chip.modelData[0])
                    }
                }
            }
        }
    }

    readonly property var minuteOptions: [[0, "NEVER"], [1, "1 MIN"], [5, "5 MIN"], [10, "10 MIN"], [12, "12 MIN"], [15, "15 MIN"], [30, "30 MIN"], [60, "60 MIN"]]

    BackButton {
        x: root.originX
        y: 96
        onActivated: root.finished()
    }

    Item {
        x: root.originX
        y: 151
        width: root.span
        height: 46

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            GlitchText {
                id: systemTitle
                anchors.verticalCenter: parent.verticalCenter
                text: "SYSTEM"
                pixelSize: 26
            }
            KanaTag {
                anchors.verticalCenter: parent.verticalCenter
                text: "設定"
                title: systemTitle
            }
        }
        NrLabel {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.accent
            text: "SAVED AND APPLIED LIVE"
        }
    }

    Row {
        x: root.originX
        y: 230
        spacing: root.span - 2 * 640

        // --- Left column -------------------------------------------------------
        Column {
            spacing: 34

            Section {
                title: "DISPLAY"

                Repeater {
                    model: root.outputs
                    ChipRow {
                        required property string modelData
                        label: root.outputs.length > 1 ? `SCALE // ${modelData}` : "INTERFACE SCALE"
                        options: SystemSettings.scales.map(s => [s, `${Math.round(s * 100)}%`])
                        current: root.scaleOf(modelData)
                        onChosen: v => SystemSettings.setScale(modelData, v)
                    }
                }
                ChipRow {
                    label: "MOTION"
                    options: [["full", "FULL"], ["reduced", "REDUCED"]]
                    current: SystemSettings.motion
                    onChosen: v => SystemSettings.setMotion(v)
                }
            }

            Section {
                title: "GAME MODE"

                ChipRow {
                    label: "WHEN FULLSCREEN"
                    options: [["auto", "AUTO"], ["off", "OFF"]]
                    current: SystemSettings.game
                    onChosen: v => SystemSettings.setGame(v)
                }
                ChipRow {
                    label: "NOTIFICATIONS"
                    options: [["hold", "HOLD"], ["show", "SHOW"]]
                    current: SystemSettings.notify
                    onChosen: v => SystemSettings.setNotify(v)
                }
            }
        }

        // --- Right column ------------------------------------------------------
        Column {
            spacing: 34

            Section {
                title: "IDLE // PLUGGED IN"

                ChipRow {
                    label: "SCREEN OFF"
                    options: root.minuteOptions
                    current: SystemSettings.idleAc.screenOff
                    onChosen: v => SystemSettings.setIdle("ac", "screenOff", v)
                }
                ChipRow {
                    label: "LOCK"
                    options: root.minuteOptions
                    current: SystemSettings.idleAc.lock
                    onChosen: v => SystemSettings.setIdle("ac", "lock", v)
                }
                ChipRow {
                    label: "SLEEP"
                    options: root.minuteOptions
                    current: SystemSettings.idleAc.sleep
                    onChosen: v => SystemSettings.setIdle("ac", "sleep", v)
                }
            }

            Section {
                title: "IDLE // ON BATTERY"
                visible: Power.present

                ChipRow {
                    label: "SCREEN OFF"
                    options: root.minuteOptions
                    current: SystemSettings.idleBattery.screenOff
                    onChosen: v => SystemSettings.setIdle("battery", "screenOff", v)
                }
                ChipRow {
                    label: "LOCK"
                    options: root.minuteOptions
                    current: SystemSettings.idleBattery.lock
                    onChosen: v => SystemSettings.setIdle("battery", "lock", v)
                }
                ChipRow {
                    label: "SLEEP"
                    options: root.minuteOptions
                    current: SystemSettings.idleBattery.sleep
                    onChosen: v => SystemSettings.setIdle("battery", "sleep", v)
                }
            }

            // A correction is flagged, in the alert colour; IDLE HOLD on the
            // bar still overrides all of this.
            Text {
                text: SystemSettings.corrected !== "" ? SystemSettings.corrected : "IDLE HOLD ON THE BAR OVERRIDES ALL OF THESE"
                color: SystemSettings.corrected !== "" ? Theme.alert : Theme.dim
                font.family: Appearance.font.data
                font.pixelSize: 9
                font.letterSpacing: 9 * 0.12
                renderType: Text.NativeRendering
            }
        }
    }
}
