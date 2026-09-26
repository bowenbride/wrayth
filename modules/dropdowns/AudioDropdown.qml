import QtQuick
import qs.components
import qs.components.ui as UI
import qs.config
import qs.services

// AUDIO (DESIGN.md): OUTPUT and INPUT, each a SectionLabel, its devices as
// Rows (type as meta) and one VolumeLine; MIXER along the bottom as the one
// full-width secondary button, echoing the bottom-left chamfer. The mixer
// slides in with the quiet BackControl and its title on the title row.
DropdownFrame {
    id: root

    title: "AUDIO"
    katakana: "音声"
    panelWidth: Tokens.measure.dropdownStandard
    showHeader: !showMixer

    property bool showMixer: false
    // Read by Dropdowns so Escape goes back a step before it closes.
    readonly property bool canGoBack: showMixer
    function goBack(): void {
        root.showMixer = false;
    }

    readonly property real surfaceHeight: implicitHeight - views.height + Math.max(mainColumn.implicitHeight, mixerColumn.implicitHeight)

    function typeOf(node: var): string {
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

    Item {
        id: views

        width: parent.width
        height: root.showMixer ? mixerColumn.implicitHeight : mainColumn.implicitHeight
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: Tokens.motion.panels
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeIn
            }
        }

        // --- Devices --------------------------------------------------------------
        Column {
            id: mainColumn

            width: parent.width
            spacing: 0
            opacity: root.showMixer ? 0 : 1
            visible: opacity > 0

            property real slide: root.showMixer ? -Tokens.motion.slide : 0
            transform: Translate {
                x: mainColumn.slide
            }
            Behavior on slide {
                NumberAnimation {
                    duration: Tokens.motion.panels
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.motion.easeIn
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.panels
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.motion.easeIn
                }
            }

            UI.SectionLabel {
                topPadding: 0
                bottomPadding: Tokens.space.s6
                text: "OUTPUT"
            }
            Repeater {
                model: Audio.outputs
                UI.ListRow {
                    required property var modelData
                    width: mainColumn.width
                    name: Demo.device(modelData.description || modelData.name || "", 1)
                    meta: root.typeOf(modelData)
                    selected: modelData === Audio.sink
                    onClicked: if (!selected) Audio.useOutput(modelData)
                }
            }
            Item {
                width: parent.width
                height: Tokens.measure.row
                UI.VolumeLine {
                    x: Tokens.measure.rowPadding
                    width: parent.width - Tokens.measure.rowPadding
                    anchors.verticalCenter: parent.verticalCenter
                    value: Audio.sink?.audio?.volume ?? 0
                    muted: Audio.sink?.audio?.muted ?? false
                    onPicked: v => Audio.setVolume(Audio.sink, v)
                    onMuteToggled: Audio.toggleMute(Audio.sink)
                }
            }

            UI.SectionLabel {
                bottomPadding: Tokens.space.s6
                text: "INPUT"
            }
            Repeater {
                model: Audio.inputs
                UI.ListRow {
                    required property var modelData
                    width: mainColumn.width
                    name: Demo.device(modelData.description || modelData.name || "", 1)
                    selected: modelData === Audio.source
                    onClicked: if (!selected) Audio.useInput(modelData)
                }
            }
            Item {
                width: parent.width
                height: Tokens.measure.row
                UI.VolumeLine {
                    x: Tokens.measure.rowPadding
                    width: parent.width - Tokens.measure.rowPadding
                    anchors.verticalCenter: parent.verticalCenter
                    mic: true
                    value: Audio.source?.audio?.volume ?? 0
                    muted: Audio.source?.audio?.muted ?? false
                    onPicked: v => Audio.setVolume(Audio.source, v)
                    onMuteToggled: Audio.toggleMute(Audio.source)
                }
            }

            Item {
                width: parent.width
                height: Tokens.measure.sectionGap
            }

            // The one framed footer button: secondary, full width, echoing the
            // panel's bottom-left chamfer.
            UI.Button {
                width: parent.width
                kind: "secondary"
                text: "MIXER"
                cutBottomLeft: Tokens.chamfer.footerButton
                onClicked: root.showMixer = true
            }
        }

        // --- The mixer: one row per app making sound -----------------------------------
        Column {
            id: mixerColumn

            width: parent.width
            spacing: Tokens.space.s10
            opacity: root.showMixer ? 1 : 0
            visible: opacity > 0

            property real slide: root.showMixer ? 0 : Tokens.motion.slide
            transform: Translate {
                x: mixerColumn.slide
            }
            Behavior on slide {
                NumberAnimation {
                    duration: Tokens.motion.panels
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.motion.easeIn
                }
            }
            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.panels
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.motion.easeIn
                }
            }

            // The title row: BackControl, then the sub-view's Title.
            Row {
                spacing: Tokens.space.s8
                height: Tokens.measure.toggleHeight
                UI.BackControl {
                    anchors.verticalCenter: parent.verticalCenter
                    destination: "AUDIO"
                    onActivated: root.showMixer = false
                }
                UI.Title {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "MIXER"
                }
            }
            UI.Rule {}

            UI.EmptyState {
                width: parent.width
                visible: Audio.streams.length === 0
                text: "NO APP IS PLAYING SOUND"
            }

            Repeater {
                model: Audio.streams.slice(0, 8)

                Column {
                    id: app

                    required property var modelData

                    width: mixerColumn.width
                    spacing: Tokens.space.s4

                    Item {
                        width: parent.width
                        height: nameText.implicitHeight

                        Text {
                            id: nameText
                            readonly property var role: Tokens.type.rowName
                            anchors.left: parent.left
                            anchors.right: stateTag.left
                            anchors.rightMargin: Tokens.space.s8
                            elide: Text.ElideRight
                            text: Audio.appName(app.modelData)
                            textFormat: Text.PlainText
                            color: Tokens.color.text
                            font.family: role.family
                            font.pixelSize: role.size
                            renderType: Text.NativeRendering
                        }
                        // PLAYING, or VOICE for a call: a status word, in signal.
                        Text {
                            id: stateTag
                            readonly property var role: Tokens.type.rowMeta
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: Audio.isCall(app.modelData) ? "VOICE" : "PLAYING"
                            color: Tokens.color.signal
                            font.family: role.family
                            font.pixelSize: role.size
                            font.letterSpacing: role.size * role.tracking
                            renderType: Text.NativeRendering
                        }
                    }
                    UI.VolumeLine {
                        width: parent.width
                        value: app.modelData.audio?.volume ?? 0
                        muted: app.modelData.audio?.muted ?? false
                        onPicked: v => Audio.setVolume(app.modelData, v)
                        onMuteToggled: Audio.toggleMute(app.modelData)
                    }
                }
            }

            UI.SectionLabel {
                visible: Audio.streams.length > 8
                text: `+${Audio.streams.length - 8} MORE`
            }
        }
    }
}
