import QtQuick
import qs.components
import qs.config
import qs.services

// AUDIO: the output and input devices (the one in use marked), each group with
// its 20-segment volume and a mute, and a MIXER view -- one row per app
// currently producing sound -- that slides in over it like Wi-Fi's settings.
// Everything is PipeWire's own state: a volume set here comes back from
// PipeWire before the meter shows it.
DropdownFrame {
    id: root

    title: "AUDIO // OUTPUT"
    titleSize: 12
    titleTracking: 0.14
    katakana: "音声"
    // Read by Dropdowns: this dropdown is 400 px wide.
    readonly property int panelWidth: 400

    property bool showMixer: false
    // Read by Dropdowns so Escape goes back a step before it closes.
    readonly property bool canGoBack: showMixer
    function goBack(): void {
        root.showMixer = false;
    }

    // The bottom-left cut every popup's bottom-edge button carries.
    readonly property int buttonCut: 8
    // The mute buttons reserve their widest label.
    readonly property int muteWidth: 84

    // Sized to the taller view, so the layer surface never reconfigures while
    // the views slide; only the visible panel's height eases.
    readonly property real surfaceHeight: implicitHeight - views.height + Math.max(mainColumn.implicitHeight, mixerColumn.implicitHeight)


    component GroupLabel: Item {
        property alias text: label.text
        property alias rightText: rightLabel.text

        width: parent.width
        height: 14

        NrLabel {
            id: label

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
        }
        NrLabel {
            id: rightLabel

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.dim
        }
    }

    // A device: its name, marked when it is the one in use. Clicking another
    // makes it the default. Fixed height, and the marker's room is reserved.
    component DeviceRow: Item {
        id: row

        required property var node
        required property bool active
        property bool showType: true
        signal chosen

        // BUILT-IN, BLUETOOTH, DISPLAY (or USB), from what PipeWire says of it.
        readonly property string type: {
            const p = node?.properties ?? {};
            const all = `${node?.name ?? ""} ${node?.description ?? ""} ${p["device.bus"] ?? ""} ${p["device.api"] ?? ""}`.toLowerCase();
            if (all.includes("bluez") || all.includes("bluetooth"))
                return "BLUETOOTH";
            if (all.includes("hdmi") || all.includes("displayport") || all.includes(" dp"))
                return "DISPLAY";
            if (all.includes("usb"))
                return "USB";
            return "BUILT-IN";
        }

        width: parent.width
        height: 32

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
        // The active device: a 2 px accent left edge.
        Rectangle {
            width: 2
            height: parent.height
            color: Theme.accent
            visible: row.active
        }

        Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 2
            color: Theme.accent
            opacity: row.active ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.duration.state
                    easing.type: Easing.OutCubic
                }
            }
        }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: inUse.left
            anchors.rightMargin: 8
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

        // ACTIVE: 9 px, the data colour; its room kept on every row.
        Text {
            id: inUse

            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "ACTIVE"
            color: Theme.signal
            opacity: row.active ? 1 : 0
            font.family: Appearance.font.data
            font.pixelSize: 9
            font.weight: Appearance.font.weightSemi
            font.letterSpacing: 9 * 0.12
            renderType: Text.NativeRendering
        }

        HoverHandler {
            id: hover

            cursorShape: row.active ? Qt.ArrowCursor : Qt.PointingHandCursor
        }
        TapHandler {
            enabled: !row.active
            onTapped: row.chosen()
        }
    }

    // A level and its mute, on one line.
    component LevelRow: Item {
        id: level

        required property var node
        property real segmentHeight: 12
        readonly property bool muted: level.node?.audio?.muted ?? false

        width: parent.width
        height: 22

        // MUTE, 52 x 22: hairline and dim, or MUTED in the accent.
        Rectangle {
            id: mute

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 52
            height: 22
            color: muteTap.pressed ? Theme.alpha(Theme.accent, 0.12) : "transparent"
            border.width: 1
            border.color: level.muted ? Theme.accent : Theme.hair
            opacity: level.node?.audio ? 1 : 0.4

            Text {
                anchors.centerIn: parent
                text: level.muted ? "MUTED" : "MUTE"
                color: level.muted ? Theme.accent : Theme.dim
                font.family: Appearance.font.data
                font.pixelSize: 9
                font.weight: Appearance.font.weightSemi
                font.letterSpacing: 9 * 0.1
                renderType: Text.NativeRendering
            }
            HoverHandler {
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                id: muteTap

                enabled: !!level.node?.audio
                onTapped: Audio.toggleMute(level.node)
            }
        }

        VolumeControl {
            anchors.left: mute.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            segmentHeight: level.segmentHeight
            usable: !!level.node?.audio
            value: level.node?.audio?.volume ?? 0
            muted: level.muted
            onChanged: v => Audio.setVolume(level.node, v)
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

        // --- Devices ---------------------------------------------------------
        Column {
            id: mainColumn

            width: parent.width
            spacing: 8
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

            Repeater {
                model: Audio.outputs
                DeviceRow {
                    required property var modelData
                    node: modelData
                    active: modelData === Audio.sink
                    onChosen: Audio.useOutput(modelData)
                }
            }
            NrLabel {
                visible: Audio.outputs.length === 0
                color: Theme.dim
                text: "NO OUTPUT DEVICE"
            }
            LevelRow {
                node: Audio.sink
            }

            Item {
                width: parent.width
                height: 6
            }

            // A hairline, then AUDIO // INPUT.
            Rectangle {
                width: parent.width
                height: Appearance.metrics.hairline
                color: Theme.hair
            }
            Text {
                text: "AUDIO // INPUT"
                color: Theme.bright
                font.family: Appearance.font.data
                font.pixelSize: 12
                font.weight: Appearance.font.weightSemi
                font.letterSpacing: 12 * 0.14
                renderType: Text.NativeRendering
            }
            Repeater {
                model: Audio.inputs
                DeviceRow {
                    required property var modelData
                    showType: false
                    node: modelData
                    active: modelData === Audio.source
                    onChosen: Audio.useInput(modelData)
                }
            }
            NrLabel {
                visible: Audio.inputs.length === 0
                color: Theme.dim
                text: "NO INPUT DEVICE"
            }
            LevelRow {
                node: Audio.source
            }

            Item {
                width: parent.width
                height: 4
            }

            // On the panel's bottom edge, so its bottom-left corner is cut to
            // match the panel.
            ActionButton {
                width: parent.width
                height: 30
                text: "MIXER"
                cutBottomLeft: root.buttonCut
                onClicked: root.showMixer = true
            }
        }

        // --- Mixer -----------------------------------------------------------
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

            BackButton {
                onActivated: root.showMixer = false
            }

            GroupLabel {
                text: "MIXER"
                rightText: Audio.streams.length === 1 ? "1 APP" : `${Audio.streams.length} APPS`
            }

            NrLabel {
                visible: Audio.streams.length === 0
                color: Theme.dim
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
                            anchors.right: callTag.left
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
                        // PLAYING, or VOICE for a call: 9 px, the data colour.
                        Text {
                            id: callTag

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

                    LevelRow {
                        node: app.modelData
                        segmentHeight: 10
                    }
                }
            }

            NrLabel {
                visible: Audio.streams.length > 8
                color: Theme.dim
                text: `+${Audio.streams.length - 8} MORE`
            }

            Item {
                width: parent.width
                height: 2
            }
        }
    }
}
