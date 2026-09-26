import QtQuick
import Quickshell
import qs.components as C
import qs.components.ui as UI
import qs.config
import qs.services

// The privacy chips at the ticker's left edge: REC while recording (the
// elapsed time, in the accent; click to stop), SHARE, MIC and CAM while an app
// is capturing the screen, the microphone or the camera (in the alert colour;
// click for which app). Only there while active: they take their room from the
// ticker, never from another readout.
Row {
    id: root

    spacing: Tokens.space.s6

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

    // An IndicatorChip (DESIGN.md) and, for SHARE, MIC and CAM, a small
    // popup naming the apps responsible. App names keep their own case.
    component Chip: UI.IndicatorChip {
        id: chip

        property var apps: []
        property bool showing: false

        onClicked: {
            if (!rec)
                showing = !showing;
        }

        PopupWindow {
            visible: chip.showing && chip.apps.length > 0
            anchor.item: chip
            anchor.rect.y: chip.height + Tokens.space.s6
            implicitWidth: popBody.implicitWidth + 2 * Tokens.space.s12
            implicitHeight: popBody.implicitHeight + 2 * Tokens.space.s8
            color: "transparent"

            C.ChamferPanel {
                anchors.fill: parent
                chamfer: Tokens.chamfer.footerButton
                fillColor: Tokens.color.panel2
                borderColor: chip.tone

                Column {
                    id: popBody

                    anchors.centerIn: parent
                    spacing: Tokens.space.s4

                    Text {
                        readonly property var role: Tokens.type.rowMeta
                        text: `${chip.text} · IN USE BY`
                        color: Tokens.color.dim
                        font.family: role.family
                        font.pixelSize: role.size
                        font.letterSpacing: role.size * role.tracking
                        renderType: Text.NativeRendering
                    }
                    Repeater {
                        model: chip.apps
                        Text {
                            required property string modelData
                            readonly property var role: Tokens.type.rowName
                            text: modelData
                            textFormat: Text.PlainText
                            color: Tokens.color.bright
                            font.family: role.family
                            font.pixelSize: role.size
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
    }

    Chip {
        visible: Recorder.recording
        rec: true
        text: `REC ${root.elapsed}`
        onClicked: Recorder.stop()
    }
    Chip {
        visible: Privacy.share.length > 0
        text: "SHARE"
        apps: Privacy.share
    }
    Chip {
        visible: Privacy.mic.length > 0
        text: "MIC"
        apps: Privacy.mic
    }
    Chip {
        visible: Privacy.cam.length > 0
        text: "CAM"
        apps: Privacy.cam
    }
}
