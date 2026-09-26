import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// The privacy chips at the ticker's left edge: REC while recording (the
// elapsed time, in the accent; click to stop), SHARE, MIC and CAM while an app
// is capturing the screen, the microphone or the camera (in the alert colour;
// click for which app). Only there while active: they take their room from the
// ticker, never from another readout.
Row {
    id: root

    spacing: 6

    readonly property bool any: Recorder.recording || Privacy.share.length > 0 || Privacy.mic.length > 0 || Privacy.cam.length > 0

    // The one clock: ticks only while recording.
    property real now: Date.now()
    Timer {
        interval: 1000
        repeat: true
        running: Recorder.recording && root.visible
        onTriggered: root.now = Date.now()
    }
    readonly property string elapsed: {
        const s = Math.max(0, Math.floor((now - Recorder.startedAt) / 1000));
        const p = n => (n < 10 ? "0" : "") + n;
        return `${p(Math.floor(s / 60))}:${p(s % 60)}`;
    }
    Connections {
        target: Recorder
        function onRecordingChanged(): void {
            root.now = Date.now();
        }
    }

    component Chip: Rectangle {
        id: chip

        property string label: ""
        property color tone: Theme.alert
        property bool pulse: false
        property var apps: []
        signal clicked

        height: 22
        width: chipRow.implicitWidth + 16
        color: hover.hovered ? Theme.alpha(tone, 0.16) : Theme.alpha(tone, 0.08)
        border.width: 1
        border.color: tone

        Row {
            id: chipRow

            anchors.centerIn: parent
            spacing: 6

            Rectangle {
                id: dot

                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                color: chip.tone

                // A gentle pulse, only while the chip is shown.
                SequentialAnimation on opacity {
                    running: chip.pulse && chip.visible
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 0.35
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
                anchors.verticalCenter: parent.verticalCenter
                text: chip.label
                color: chip.tone
                font.family: Appearance.font.data
                font.pixelSize: 9
                font.weight: Appearance.font.weightSemi
                font.letterSpacing: 9 * 0.14
                font.features: Appearance.tabularFigures
                renderType: Text.NativeRendering
            }
        }
        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: chip.clicked()
        }

        // Which app, in a small popup under the chip.
        property bool showing: false
        PopupWindow {
            visible: chip.showing && chip.apps.length > 0
            anchor.item: chip
            anchor.rect.y: chip.height + 6
            implicitWidth: popBody.implicitWidth + 24
            implicitHeight: popBody.implicitHeight + 18
            color: "transparent"

            ChamferPanel {
                anchors.fill: parent
                chamfer: 8
                fillColor: Theme.panel2
                borderColor: chip.tone

                Column {
                    id: popBody

                    anchors.centerIn: parent
                    spacing: 4

                    Text {
                        text: `${chip.label} // IN USE BY`
                        color: Theme.dim
                        font.family: Appearance.font.data
                        font.pixelSize: 9
                        font.letterSpacing: 9 * 0.14
                        renderType: Text.NativeRendering
                    }
                    Repeater {
                        model: chip.apps
                        Text {
                            required property string modelData
                            text: modelData.toUpperCase()
                            textFormat: Text.PlainText
                            color: Theme.bright
                            font.family: Appearance.font.data
                            font.pixelSize: 11
                            font.weight: Appearance.font.weightSemi
                            renderType: Text.NativeRendering
                        }
                    }
                }
            }
        }
        Timer {
            running: chip.showing
            interval: 4000
            onTriggered: chip.showing = false
        }
        onClicked: showing = !showing
    }

    Chip {
        visible: Recorder.recording
        label: `REC ${root.elapsed}`
        tone: Theme.accent
        pulse: true
        onClicked: Recorder.stop()
    }
    Chip {
        visible: Privacy.share.length > 0
        label: "SHARE"
        apps: Privacy.share
    }
    Chip {
        visible: Privacy.mic.length > 0
        label: "MIC"
        apps: Privacy.mic
    }
    Chip {
        visible: Privacy.cam.length > 0
        label: "CAM"
        apps: Privacy.cam
    }
}
