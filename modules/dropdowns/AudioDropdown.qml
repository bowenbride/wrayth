import QtQuick
import qs.components
import qs.config
import qs.services

// AUDIO: one panel. OUTPUT (the devices, then one volume line with the
// speaker as its mute), INPUT (the same, with the microphone), and MIXER
// along the bottom, which slides to one row per app making sound. Everything
// is PipeWire's own state: a volume set here comes back from PipeWire before
// the meter shows it.
DropdownFrame {
    id: root

    title: "AUDIO"
    katakana: "音声"
    // Read by Dropdowns: this dropdown is 380 px wide.
    readonly property int panelWidth: 380

    property bool showMixer: false
    // Read by Dropdowns so Escape goes back a step before it closes.
    readonly property bool canGoBack: showMixer
    function goBack(): void {
        root.showMixer = false;
    }

    // Sized to the taller view, so the layer surface never reconfigures while
    // the views slide; only the visible panel's height eases.
    readonly property real surfaceHeight: implicitHeight - views.height + Math.max(mainColumn.implicitHeight, mixerColumn.implicitHeight)

    // A quiet section label: 9 px, 0.18em, dim.
    component SectionLabel: Text {
        color: Theme.dim
        font.family: Appearance.font.data
        font.pixelSize: 9
        font.weight: Appearance.font.weightSemi
        font.letterSpacing: 9 * 0.18
        renderType: Text.NativeRendering
    }

    // A device: 30 px; the active one with a 2 px accent edge, a subtle dark
    // fill and its name in bright; its type at 10 px dim.
    component DeviceRow: Item {
        id: row

        required property var node
        required property bool active
        property bool showType: true
        signal chosen

        readonly property string type: {
            const p = node?.properties ?? {};
            const all = `${node?.name ?? ""} ${node?.description ?? ""} ${p["device.bus"] ?? ""} ${p["device.api"] ?? ""}`.toLowerCase();
            if (all.includes("bluez") || all.includes("bluetooth"))
                return "BLUETOOTH";
            if (all.includes("hdmi") || all.includes("displayport"))
                return "DISPLAY";
            if (all.includes("usb"))
                return "USB";
            return "BUILT-IN";
        }

        width: parent.width
        height: 30

        Rectangle {
            anchors.fill: parent
            color: row.active ? Theme.alpha(Theme.ground, 0.55) : (hover.hovered ? Theme.cell : "transparent")
            Behavior on color {
                ColorAnimation {
                    duration: Appearance.duration.state
                    easing.type: Easing.OutCubic
                }
            }
        }
        Rectangle {
            width: 2
            height: parent.height
            color: Theme.accent
            visible: row.active
        }
        Feedback {
            id: feedback
            anchors.fill: parent
        }
        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8
            clip: true

            Text {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - (typeLabel.visible ? typeLabel.implicitWidth + 8 : 0))
                elide: Text.ElideRight
                text: Demo.device(row.node?.description || row.node?.name || "", 1)
                textFormat: Text.PlainText
                color: row.active ? Theme.bright : Theme.text
                font.family: Appearance.font.data
                font.pixelSize: 11
                font.weight: row.active ? Appearance.font.weightSemi : Appearance.font.weightRegular
                renderType: Text.NativeRendering
            }
            Text {
                id: typeLabel
                visible: row.showType
                anchors.verticalCenter: parent.verticalCenter
                text: row.type
                color: Theme.dim
                font.family: Appearance.font.data
                font.pixelSize: 10
                font.letterSpacing: 10 * 0.1
                renderType: Text.NativeRendering
            }
        }
        HoverHandler {
            id: hover
            cursorShape: row.active ? Qt.ArrowCursor : Qt.PointingHandCursor
        }
        TapHandler {
            enabled: !row.active
            onPressedChanged: if (pressed) feedback.flash()
            onTapped: row.chosen()
        }
    }

    // One volume line: 20 segments, the percentage, and the icon at the end
    // as the mute toggle (crossed out in the accent while muted).
    component VolumeLine: Item {
        id: line

        required property var node
        property string icon: "volume_up"
        property string mutedIcon: "volume_off"
        property real segmentHeight: 10
        readonly property bool muted: node?.audio?.muted ?? false

        width: parent.width
        height: 20

        VolumeControl {
            anchors.left: parent.left
            anchors.right: muteIcon.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            segmentHeight: line.segmentHeight
            usable: !!line.node?.audio
            value: line.node?.audio?.volume ?? 0
            muted: line.muted
            onChanged: v => Audio.setVolume(line.node, v)
        }
        Item {
            id: muteIcon

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: 20
            height: 20

            Icon {
                anchors.centerIn: parent
                name: line.muted ? line.mutedIcon : line.icon
                size: 16
                color: line.muted ? Theme.accent : (muteHover.hovered ? Theme.text : Theme.dim)
            }
            HoverHandler {
                id: muteHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                enabled: !!line.node?.audio
                onTapped: Audio.toggleMute(line.node)
            }
        }
    }

    Item {
        id: views

        width: parent.width
        height: root.showMixer ? mixerColumn.implicitHeight : mainColumn.implicitHeight
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: Appearance.duration.panel
                easing.type: Easing.OutCubic
            }
        }

        // --- Devices ------------------------------------------------------------
        Column {
            id: mainColumn

            width: parent.width
            spacing: 0
            opacity: root.showMixer ? 0 : 1
            visible: opacity > 0

            property real slide: root.showMixer ? -width : 0
            transform: Translate {
                x: mainColumn.slide
            }
            Behavior on slide {
                NumberAnimation {
                    duration: Appearance.duration.panel
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.duration.panel
                    easing.type: Easing.OutCubic
                }
            }

            SectionLabel {
                height: 20
                verticalAlignment: Text.AlignVCenter
                text: "OUTPUT"
            }
            Repeater {
                model: Audio.outputs
                DeviceRow {
                    required property var modelData
                    node: modelData
                    active: modelData === Audio.sink
                    onChosen: Audio.useOutput(modelData)
                }
            }
            // Indented under the devices.
            Item {
                width: parent.width
                height: 30
                VolumeLine {
                    x: 12
                    width: parent.width - 12
                    anchors.verticalCenter: parent.verticalCenter
                    node: Audio.sink
                }
            }

            Item {
                width: parent.width
                height: 12
            }

            SectionLabel {
                height: 20
                verticalAlignment: Text.AlignVCenter
                text: "INPUT"
            }
            Repeater {
                model: Audio.inputs
                DeviceRow {
                    required property var modelData
                    node: modelData
                    showType: false
                    active: modelData === Audio.source
                    onChosen: Audio.useInput(modelData)
                }
            }
            Item {
                width: parent.width
                height: 30
                VolumeLine {
                    x: 12
                    width: parent.width - 12
                    anchors.verticalCenter: parent.verticalCenter
                    node: Audio.source
                    icon: "mic"
                    mutedIcon: "mic_off"
                }
            }

            Item {
                width: parent.width
                height: 10
            }

            // Secondary, in the panel's bottom-left corner: its chamfer.
            ActionButton {
                width: parent.width
                height: 28
                text: "MIXER"
                cutBottomLeft: 8
                onClicked: root.showMixer = true
            }
        }

        // --- The mixer: one row per app making sound -------------------------------
        Column {
            id: mixerColumn

            width: parent.width
            spacing: 10
            opacity: root.showMixer ? 1 : 0
            visible: opacity > 0

            property real slide: root.showMixer ? 0 : width
            transform: Translate {
                x: mixerColumn.slide
            }
            Behavior on slide {
                NumberAnimation {
                    duration: Appearance.duration.panel
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.duration.panel
                    easing.type: Easing.OutCubic
                }
            }

            // "‹ AUDIO" and MIXER on one row.
            Item {
                width: parent.width
                height: 22
                QuietBack {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    label: "AUDIO"
                    onActivated: root.showMixer = false
                }
                Text {
                    anchors.centerIn: parent
                    text: "MIXER"
                    color: Theme.bright
                    font.family: Appearance.font.data
                    font.pixelSize: 11
                    font.weight: Appearance.font.weightSemi
                    font.letterSpacing: 11 * 0.14
                    renderType: Text.NativeRendering
                }
            }

            SectionLabel {
                visible: Audio.streams.length === 0
                text: "NO APP IS PLAYING SOUND"
            }

            Repeater {
                model: Audio.streams.slice(0, 8)

                Column {
                    id: app

                    required property var modelData

                    width: parent.width
                    spacing: 4

                    Item {
                        width: parent.width
                        height: 16

                        Text {
                            anchors.left: parent.left
                            anchors.right: stateTag.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            elide: Text.ElideRight
                            text: Audio.appName(app.modelData)
                            textFormat: Text.PlainText
                            color: Theme.bright
                            font.family: Appearance.font.data
                            font.pixelSize: 11
                            font.weight: Appearance.font.weightSemi
                            renderType: Text.NativeRendering
                        }
                        Text {
                            id: stateTag
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: Audio.isCall(app.modelData) ? "VOICE" : "PLAYING"
                            color: Theme.signal
                            font.family: Appearance.font.data
                            font.pixelSize: 9
                            font.weight: Appearance.font.weightSemi
                            font.letterSpacing: 9 * 0.12
                            renderType: Text.NativeRendering
                        }
                    }
                    VolumeLine {
                        node: app.modelData
                    }
                }
            }

            SectionLabel {
                visible: Audio.streams.length > 8
                text: `+${Audio.streams.length - 8} MORE`
            }
            Item {
                width: parent.width
                height: 2
            }
        }
    }
}
