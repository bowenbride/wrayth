import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.components.ui as UI
import qs.config
import qs.services

// RECORD (Super + Shift + R, or the launcher): what to record, with what
// sound, at what rate, then START RECORDING. REGION hands over to the
// screenshot selector. The REC chip on the bar, or the same key, stops it.
Variants {
    model: ShellState.screens

    PanelWindow {
        id: overlay

        required property ShellScreen modelData
        readonly property bool shown: ShellState.recordOpen && ShellState.overlayScreen === modelData?.name

        screen: modelData
        color: "transparent"
        visible: shown

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "wrayth-overlay"
        WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        onShownChanged: if (shown) Recorder.recheck()

        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: 0.45
        }
        MouseArea {
            anchors.fill: parent
            onClicked: ShellState.recordOpen = false
        }

        // A label column (70 px) and Chips, one row per choice.
        component ChipRow: Row {
            id: chipRow

            property string label: ""
            property var options: []
            property var current
            signal chosen(var value)

            spacing: 0

            UI.Label {
                width: 70
                height: Tokens.measure.chip
                verticalAlignment: Text.AlignVCenter
                text: chipRow.label
            }
            Row {
                spacing: Tokens.space.s6
                Repeater {
                    model: chipRow.options
                    UI.Chip {
                        required property var modelData
                        text: modelData[1]
                        selected: chipRow.current === modelData[0]
                        onClicked: chipRow.chosen(modelData[0])
                    }
                }
            }
        }

        // The centred-panel template (DESIGN.md): 16 px chamfers, panel2.
        ChamferPanel {
            id: panel

            anchors.centerIn: parent
            width: Tokens.measure.dropdownStandard
            height: body.implicitHeight + 2 * Tokens.space.s16
            chamfer: Tokens.chamfer.centred
            fillColor: Tokens.color.panel2

            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: body

                x: Tokens.space.s16
                y: Tokens.space.s16
                width: parent.width - 2 * Tokens.space.s16
                spacing: Tokens.space.s12

                // Header: Title + JapaneseLabel, a hint line on the right.
                Item {
                    width: parent.width
                    height: Tokens.measure.toggleHeight
                    UI.Title {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: "RECORD"
                        japanese: "録画"
                    }
                    Text {
                        readonly property var role: Tokens.type.hint
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: Recorder.available ? "ENTER STARTS · ESC CLOSES" : "INSTALL WF-RECORDER"
                        color: Recorder.available ? Tokens.color.dim : Tokens.color.alert
                        font.family: role.family
                        font.pixelSize: role.size
                        font.letterSpacing: role.size * role.tracking
                        renderType: Text.NativeRendering
                    }
                }
                UI.Rule {}

                ChipRow {
                    label: "CAPTURE"
                    options: [["region", "REGION"], ["window", "WINDOW"], ["screen", "SCREEN"]]
                    current: Recorder.capture
                    onChosen: v => Recorder.capture = v
                }
                ChipRow {
                    label: "AUDIO"
                    options: [["off", "OFF"], ["system", "SYSTEM"], ["both", "SYSTEM + MIC"]]
                    current: Recorder.audio
                    onChosen: v => Recorder.audio = v
                }
                ChipRow {
                    label: "FRAMES"
                    options: [[30, "30"], [60, "60"]]
                    current: Recorder.fps
                    onChosen: v => Recorder.fps = v
                }

                Text {
                    readonly property var role: Tokens.type.hint
                    width: parent.width
                    elide: Text.ElideRight
                    text: "SAVED TO ~/VIDEOS/RECORDINGS · STOP WITH THE REC CHIP"
                    color: Tokens.color.dim
                    font.family: role.family
                    font.pixelSize: role.size
                    font.letterSpacing: role.size * role.tracking
                    renderType: Text.NativeRendering
                }

                // The view's primary action, full width, in the panel's
                // bottom-left corner: its chamfer echoes it.
                UI.Button {
                    width: parent.width
                    kind: "primary"
                    text: "START RECORDING"
                    enabled: Recorder.available
                    cutBottomLeft: Tokens.chamfer.footerButton
                    onClicked: Recorder.start()
                }
            }
        }

        OverlayKeys {
            anchors.fill: parent
            active: overlay.shown
            onEscaped: ShellState.recordOpen = false
            Keys.onReturnPressed: Recorder.start()
        }
    }
}
