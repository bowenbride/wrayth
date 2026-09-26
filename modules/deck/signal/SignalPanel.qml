import QtQuick
import qs.components
import qs.config
import qs.services

// SIGNAL // AUDIO: the deck's spectrum, on the bottom row's line beside the
// planner and vuln watch.
ChamferPanel {
    id: root

    readonly property real padding: 14

    // The mirror of the HUD above it: cut top-left and bottom-right, with the
    // accent brackets on the two square corners. See the deck corner scheme.
    chamfer: Appearance.chamfer.panel
    chamferTopLeft: chamfer
    chamferTopRight: 0
    chamferBottomRight: chamfer
    chamferBottomLeft: 0
    fillColor: Tokens.color.panel

    CornerBrackets {
        inset: 6
        corners: ["topRight", "bottomLeft"]
    }

    // --- Header: SIGNAL 信号 ................................ state ---------
    readonly property var source: Media.current
    readonly property bool media: source?.kind === "media"
    readonly property bool call: source?.kind === "call"
    readonly property var player: media ? source.player : null
    readonly property string stateText: call ? "IN CALL" : media ? (player?.isPlaying ? "LIVE" : "PAUSED") : ""

    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.padding
        height: 18

        GlitchFx {
            group: "deck"
            key: "panel:signal"
            textual: true
            fills: true
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: signalHeaderRow.implicitWidth
            height: signalHeaderRow.implicitHeight
            scrambleItems: [signalTitle]

            Row {
                id: signalHeaderRow

                anchors.fill: parent
                spacing: 8

                Text {
                    id: signalTitle

                    anchors.verticalCenter: parent.verticalCenter
                    text: "SIGNAL"
                    color: Tokens.color.text
                    font.family: Tokens.font.data
                    font.pixelSize: 11
                    font.weight: Tokens.font.dataWeight
                    font.letterSpacing: 11 * 0.14
                    renderType: Text.NativeRendering
                }

                KanaTag {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "信号"
                    title: signalTitle
                }
            }
        }

        // The state: LIVE while playing, PAUSED, IN CALL. In a slot as wide
        // as its widest word, right-aligned, so nothing moves between them.
        Item {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: widest.implicitWidth
            height: widest.implicitHeight

            Text {
                id: widest

                visible: false
                text: "IN CALL"
                font: stateLabel.font
            }
            Text {
                id: stateLabel

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: root.stateText
                color: root.call || root.stateText === "LIVE" ? Tokens.color.accent : Tokens.color.dim
                font.family: Tokens.font.data
                font.pixelSize: 10
                font.weight: Tokens.font.dataWeight
                font.letterSpacing: 10 * 0.12
                renderType: Text.NativeRendering

                Behavior on color {
                    ColorAnimation {
                        duration: Tokens.motion.feedback
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.motion.easeIn
                    }
                }
            }
        }
    }

    // Position is not pushed by MPRIS; it is read while it can be seen moving.
    Timer {
        interval: 1000
        repeat: true
        running: ShellState.deckVisible && !!root.player && root.player.isPlaying && root.player.positionSupported
        onTriggered: root.player.positionChanged()
    }
    // A call's duration, likewise only while the deck is up.
    property real now: Date.now()
    Timer {
        interval: 1000
        repeat: true
        running: ShellState.deckVisible && root.call
        onTriggered: root.now = Date.now()
    }

    function clock(seconds: real): string {
        const s = Math.max(0, Math.floor(seconds));
        const h = Math.floor(s / 3600);
        const mm = String(Math.floor(s / 60) % 60).padStart(h > 0 ? 2 : 1, "0");
        const ss = String(s % 60).padStart(2, "0");
        return h > 0 ? `${h}:${mm}:${ss}` : `${mm}:${ss}`;
    }

    // --- Source chips, when there are two or more -----------------------------
    Flickable {
        id: chips

        readonly property bool wanted: Media.sources.length > 1

        anchors.top: header.bottom
        anchors.topMargin: wanted ? 8 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        height: wanted ? 22 : 0
        opacity: wanted ? 1 : 0
        visible: height > 0
        contentWidth: chipRow.implicitWidth
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.HorizontalFlick

        Behavior on height {
            NumberAnimation {
                duration: Tokens.motion.panels
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeIn
            }
        }
        Behavior on anchors.topMargin {
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

        Row {
            id: chipRow

            spacing: 6

            Repeater {
                model: Media.sources

                // A chip is a button: hover, press and a keyboard-free click.
                Rectangle {
                    id: chip

                    required property var modelData
                    readonly property bool selected: root.source?.key === modelData.key
                    readonly property bool sounding: modelData.kind === "call" || (modelData.player?.isPlaying ?? false)

                    width: 8 + 5 + 6 + chipLabel.implicitWidth + 8
                    height: 22
                    color: selected ? Tokens.color.accentTint : (chipHover.hovered ? Theme.cell : "transparent")
                    border.width: 1
                    border.color: selected ? Tokens.color.accent : Tokens.color.hair

                    Behavior on color {
                        ColorAnimation {
                            duration: Tokens.motion.feedback
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.motion.easeIn
                        }
                    }
                    Behavior on border.color {
                        ColorAnimation {
                            duration: Tokens.motion.feedback
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.motion.easeIn
                        }
                    }

                    Rectangle {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 5
                        height: 5
                        color: chip.sounding ? Tokens.color.signal : Tokens.color.mute
                    }
                    Text {
                        id: chipLabel

                        x: 8 + 5 + 6
                        anchors.verticalCenter: parent.verticalCenter
                        text: Media.labelOf(chip.modelData)
                        textFormat: Text.PlainText
                        color: chip.selected ? Tokens.color.accent : Tokens.color.text
                        font.family: Tokens.font.data
                        font.pixelSize: 9
                        font.weight: Tokens.font.dataWeight
                        font.letterSpacing: 9 * 0.12
                        renderType: Text.NativeRendering
                    }

                    HoverHandler {
                        id: chipHover

                        cursorShape: Qt.PointingHandCursor
                    }
                    TapHandler {
                        onTapped: Media.select(chip.modelData.key)
                    }
                }
            }
        }
    }

    // --- The now-playing block, a fixed height at the bottom ---------------------
    // Fixed whatever is selected -- media, a call or nothing -- so the spectrum
    // above it never changes size.
    Item {
        id: now

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.bottomMargin: root.padding
        height: 1 + 10 + 18 + 3 + 13 + 10 + 12 + 10 + 26

        Rectangle {
            id: divider

            anchors.top: parent.top
            width: parent.width
            height: Tokens.measure.hairline
            color: Tokens.color.hair
        }

        Text {
            id: title

            anchors.top: divider.bottom
            anchors.topMargin: 10
            width: parent.width
            height: 18
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            text: root.call ? "VOICE CALL" : root.media ? (root.player?.trackTitle || "UNTITLED") : "NO SIGNAL"
            textFormat: Text.PlainText
            color: root.source ? Tokens.color.bright : Tokens.color.dim
            font.family: Tokens.font.display
            font.pixelSize: 15
            font.weight: Tokens.font.displayWeight
            renderType: Text.NativeRendering
        }

        // ARTIST · SOURCE, or for a call APP · N IN CALL · DURATION.
        Text {
            id: meta

            anchors.top: title.bottom
            anchors.topMargin: 3
            width: parent.width
            height: 13
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
            textFormat: Text.PlainText
            color: Tokens.color.dim
            font.family: Tokens.font.data
            font.pixelSize: 10
            renderType: Text.NativeRendering
            text: {
                if (root.call) {
                    const parts = [root.source.app.toUpperCase()];
                    const n = root.source.node?.properties?.["wrayth.call.members"];
                    if (n)
                        parts.push(`${n} IN CALL`);
                    const started = Media.callStarts[root.source.key];
                    if (started)
                        parts.push(root.clock((root.now - started) / 1000));
                    return parts.join(" · ");
                }
                if (root.media) {
                    const artist = (root.player?.trackArtist || "").toUpperCase();
                    return [artist, Media.labelOf(root.source)].filter(x => x).join(" · ");
                }
                return "";
            }
        }

        // --- Media: progress, then the controls ------------------------------
        Item {
            id: progress

            anchors.top: meta.bottom
            anchors.topMargin: 10
            width: parent.width
            height: 12
            visible: opacity > 0
            opacity: root.media ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.feedback
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.motion.easeIn
                }
            }

            Text {
                id: pos

                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                text: root.player && root.player.positionSupported ? root.clock(root.player.position) : "--:--"
                color: Tokens.color.dim
                font.family: Tokens.font.data
                font.pixelSize: 9
                renderType: Text.NativeRendering
            }
            Rectangle {
                anchors.left: pos.right
                anchors.right: len.left
                anchors.verticalCenter: parent.verticalCenter
                height: 2
                color: Tokens.color.track

                Rectangle {
                    height: parent.height
                    width: root.player && root.player.lengthSupported && root.player.length > 0
                        ? parent.width * Math.min(1, root.player.position / root.player.length) : 0
                    color: Tokens.color.signal

                    Behavior on width {
                        NumberAnimation {
                            duration: Tokens.motion.movement
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.motion.easeIn
                        }
                    }
                }
            }
            Text {
                id: len

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                horizontalAlignment: Text.AlignRight
                text: root.player && root.player.lengthSupported ? root.clock(root.player.length) : "--:--"
                color: Tokens.color.dim
                font.family: Tokens.font.data
                font.pixelSize: 9
                renderType: Text.NativeRendering
            }
        }

        component TransportButton: Rectangle {
            id: tb

            property string glyph: "play"
            property bool accented: false
            property bool usable: true
            signal clicked

            height: 26
            color: accented ? Theme.alpha(Tokens.color.accent, press.pressed ? 0.24 : 0.12) : (press.pressed ? Tokens.color.accentTint : "transparent")
            border.width: 1
            border.color: accented ? Tokens.color.accent : Tokens.color.hair
            opacity: usable ? 1 : 0.4

            Behavior on color {
                ColorAnimation {
                    duration: Tokens.motion.feedback
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.motion.easeIn
                }
            }

            MediaGlyph {
                anchors.centerIn: parent
                kind: tb.glyph
                color: tb.accented ? Tokens.color.accent : Tokens.color.text
            }
            HoverHandler {
                cursorShape: tb.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
            }
            TapHandler {
                id: press

                enabled: tb.usable
                onTapped: tb.clicked()
            }
        }

        Row {
            id: controls

            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 10
            visible: opacity > 0
            opacity: root.media ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.feedback
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.motion.easeIn
                }
            }

            TransportButton {
                width: 38
                glyph: "previous"
                usable: !!root.player && root.player.canGoPrevious
                onClicked: root.player.previous()
            }
            TransportButton {
                width: 50
                glyph: root.player?.isPlaying ? "pause" : "play"
                accented: true
                usable: !!root.player && root.player.canTogglePlaying
                onClicked: root.player.togglePlaying()
            }
            TransportButton {
                width: 38
                glyph: "next"
                usable: !!root.player && root.player.canGoNext
                onClicked: root.player.next()
            }
        }

        // --- A call: a note, and OPEN CALL. No mute, deafen or leave. ---------
        Item {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 26
            visible: opacity > 0
            opacity: root.call ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.feedback
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.motion.easeIn
                }
            }

            Text {
                anchors.left: parent.left
                anchors.right: openCall.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: "Mute, deafen and leave live in the app."
                color: Tokens.color.dim
                font.family: Tokens.font.data
                font.pixelSize: 9
                renderType: Text.NativeRendering
            }
            Rectangle {
                id: openCall

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: openLabel.implicitWidth + 24
                height: 26
                color: Theme.alpha(Tokens.color.accent, callPress.pressed ? 0.24 : 0.12)
                border.width: 1
                border.color: Tokens.color.accent

                Text {
                    id: openLabel

                    anchors.centerIn: parent
                    text: "OPEN CALL"
                    color: Tokens.color.accent
                    font.family: Tokens.font.data
                    font.pixelSize: 10
                    font.weight: Tokens.font.dataWeight
                    font.letterSpacing: 10 * 0.12
                    renderType: Text.NativeRendering
                }
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    id: callPress

                    onTapped: Media.openCall(root.source)
                }
            }
        }
    }

    // --- The spectrum: between the chips and the divider ---------------------
    // Follows the selected source only; flat when nothing plays.
    GlitchFx {
        group: "deck"
        fills: true

        anchors.top: chips.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: now.top
        anchors.bottomMargin: 8
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding

        Spectrum {
            anchors.fill: parent

            values: root.source ? Cava.levels : []
        }
    }
}
