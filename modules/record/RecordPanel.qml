import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.components
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

        component ChipRow: Row {
            id: chipRow

            property string label: ""
            property var options: []
            property var current
            signal chosen(var value)

            Text {
                width: 70
                height: 24
                verticalAlignment: Text.AlignVCenter
                text: chipRow.label
                color: Theme.dim
                font.family: Appearance.font.data
                font.pixelSize: 9
                font.letterSpacing: 9 * 0.14
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

        ChamferPanel {
            id: panel

            anchors.centerIn: parent
            width: 400
            height: body.implicitHeight + 28
            chamfer: Appearance.chamfer.panel
            fillColor: Theme.panel2

            MouseArea {
                anchors.fill: parent
            }

            Column {
                id: body

                x: 14
                y: 14
                width: parent.width - 28
                spacing: 12

                Item {
                    width: parent.width
                    height: 22
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8
                        NrLabel {
                            id: recTitle
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.bright
                            text: "RECORD"
                        }
                        KanaTag {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "録画"
                            title: recTitle
                        }
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: !Recorder.available
                        text: "WF-RECORDER NOT INSTALLED"
                        color: Theme.alert
                        font.family: Appearance.font.data
                        font.pixelSize: 9
                        font.letterSpacing: 9 * 0.12
                        renderType: Text.NativeRendering
                    }
                }
                Rectangle {
                    width: parent.width
                    height: Appearance.metrics.hairline
                    color: Theme.hair
                }

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
                    width: parent.width
                    elide: Text.ElideRight
                    text: "SAVED TO ~/VIDEOS/RECORDINGS · STOP WITH THE REC CHIP"
                    color: Theme.dim
                    font.family: Appearance.font.data
                    font.pixelSize: 9
                    font.letterSpacing: 9 * 0.08
                    renderType: Text.NativeRendering
                }

                // On the panel's bottom edge: the bottom-left cut.
                ActionButton {
                    width: parent.width
                    height: 30
                    text: "START RECORDING"
                    accented: true
                    usable: Recorder.available
                    cutBottomLeft: 8
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
