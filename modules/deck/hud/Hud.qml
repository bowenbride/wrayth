import QtQuick
import qs.components
import qs.config
import qs.services
import qs.utils

// SYS.DIAG: the deck's right-hand column. Header, CPU, MEM, NET, the daemon
// lines and the footer, in the order the spec lists them.
ChamferPanel {
    id: root

    // Contain everything to the panel: on a short screen the sections can be
    // taller than the column, and without this they would spill over the panel
    // below. Clipped, the worst case is a section cut off, never an overlap.
    clip: true

    readonly property real padding: 16

    // A daemon's detail view takes over the daemon area and the footer's space
    // when one is open. The daemon rows, their label and the footer fade out;
    // the detail fades in below the name, which lifts up to the label's place.
    readonly property bool detailActive: Daemons.expanded !== ""
    readonly property var detailEntry: Daemons.entry(Daemons.expanded) ?? ({
            id: "",
            name: "",
            description: ""
        })
    readonly property int detailIndex: Daemons.selected.indexOf(Daemons.expanded)

    chamfer: Appearance.chamfer.hud
    fillColor: Theme.panel

    CornerBrackets {
        inset: 6
    }

    Column {
        id: column

        // Bottom-anchored to the footer, not filling the panel, so the sections
        // clip *above* the footer on a short screen instead of drawing over it.
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: footer.top
        anchors.margins: root.padding
        anchors.bottomMargin: 8
        clip: true

        // The deck's height varies with whatever else reserves screen space, so
        // the gaps close up rather than letting the sections run into the
        // bottom-anchored footer.
        spacing: Math.max(8, Math.min(16, (root.height - 560) / 8))

        // --- Header --------------------------------------------------------
        // The deck opening fires this one first, then the three panel headers
        // after it -- the one stagger the animation rules allow, because these
        // are sibling panels rather than children of one.
        GlitchFx {
            group: "deck"
            id: diagFx

            key: "diag"
            textual: true
            fills: true
            width: parent.width
            height: title.height
            scrambleItems: [title]

        Item {
            anchors.fill: parent

            GlitchText {
                id: title

                text: "SYS.DIAG"
                pixelSize: 28
            }

            Text {
                anchors.left: title.right
                anchors.leftMargin: 10
                anchors.baseline: title.bottom
                anchors.baselineOffset: -6

                text: "システム診断"
                color: Theme.signal
                font.family: Appearance.font.accent
                font.pixelSize: Appearance.size.katakana
                font.weight: Appearance.font.weightMedium
                renderType: Text.NativeRendering
            }
        }
        }

        // Two readings, divided by space and colour rather than a slash: the
        // labels dim, the values in the text colour.
        Row {
            width: parent.width
            spacing: 16

            Row {
                spacing: 6
                NrLabel { text: "HOST" }
                NrLabel { color: Theme.text; text: Demo.host(Machine.hostname) }
            }

            Row {
                spacing: 6
                NrLabel { text: "UPLINK" }
                NrLabel { color: Theme.text; text: SystemStatus.ssid ? Demo.ssid(SystemStatus.ssid).toUpperCase() : "OFFLINE" }
            }
        }

        Item {
            width: parent.width
            height: 11

            HazardStripes {
                implicitWidth: 96
                height: parent.height
            }
        }

        Rectangle {
            width: parent.width
            height: Appearance.metrics.hairline
            color: Theme.hair
        }

        // Opens the profile picker. The spec gives the picker no keybind of its
        // own, so this label is one of only two ways in.
        Item {
            width: parent.width
            height: profile.height

            NrLabel {
                id: profile

                text: `PROFILE${Appearance.separator}${Theme.profile.toUpperCase()}`
                color: hover.hovered ? Theme.bright : Theme.dim
            }

            HoverHandler {
                id: hover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: ShellState.openExclusive("picker")
            }
        }

        // --- CPU -----------------------------------------------------------
        HudSection {
            label: `CPU${Appearance.separator}${Machine.cpuModel}`

            Column {
                width: parent.width
                spacing: 10

                // A graph is as glitchable as a word. SPLIT and SLICE apply
                // to anything in the shell; only SCRAMBLE is restricted, and
                // there is nothing here to scramble.
                GlitchFx {
                    group: "deck"
                    fills: true

                    width: parent.width
                    height: bars.implicitHeight
                    numeric: true

                    ThreadBars {
                        id: bars

                        anchors.fill: parent
                        values: SysInfo.cpuThreads
                        animate: ShellState.deckVisible
                    }
                }

                Item {
                    width: parent.width
                    height: load.height

                    Readout {
                        id: load

                        label: "LOAD"
                        // The widest each of these can ever be, so the two
                        // readouts beside them never move when a figure does.
                        valueReserve: "100%"
                        value: Fmt.percent(SysInfo.cpuPercent)
                    }

                    Readout {
                        anchors.horizontalCenter: parent.horizontalCenter
                        label: "TEMP"
                        valueReserve: "100°C"
                        value: Diag.tempC < 0 ? "--" : `${Math.round(Diag.tempC)}°C`
                    }

                    Readout {
                        anchors.right: parent.right
                        label: "FREQ"
                        valueReserve: "9.99 GHZ"
                        value: `${Diag.freqGhz.toFixed(2)} GHZ`
                    }
                }
            }
        }

        // --- MEM -----------------------------------------------------------
        HudSection {
            // Fmt.gib's decimals argument is typed, so leaving it out passes 0
            // rather than the default -- hence the explicit 1.
            label: `MEM${Appearance.separator}${Fmt.gib(SysInfo.memUsedGib, 1)} / ${Fmt.gib(SysInfo.memTotalGib, 1)} GB`
            trailing: Fmt.percent(SysInfo.memPercent)

            Column {
                width: parent.width
                spacing: 8

                SegmentMeter {
                    width: parent.width
                    segments: 20
                    segmentWidth: (parent.width - 19 * 3) / 20
                    segmentHeight: 12
                    spacing: 3
                    value: SysInfo.memPercent / 100
                    // /proc/meminfo twice a second against a 900 ms ease is
                    // an animation that never stops. Not while nobody is
                    // looking at it.
                    animate: ShellState.deckVisible
                }
            }
        }

        // --- NET -----------------------------------------------------------
        HudSection {
            label: `NET${Appearance.separator}${Machine.netInterface}`

            Column {
                width: parent.width
                spacing: 8

                Sparkline {
                    width: parent.width
                    height: 48
                    points: 13
                    downValues: SysInfo.netRxHistory
                    upValues: SysInfo.netTxHistory
                }

                Item {
                    width: parent.width
                    height: up.height

                    Readout {
                        id: up

                        label: "▲ UP"
                        valueReserve: "999.9 KB/s"
                        value: Fmt.rateLong(SysInfo.netTxRate)
                        valueColor: Theme.accent
                    }

                    Readout {
                        anchors.right: parent.right
                        label: "▼ DOWN"
                        valueReserve: "999.9 KB/s"
                        value: Fmt.rateLong(SysInfo.netRxRate)
                        valueColor: Theme.signal
                    }
                }
            }
        }

        // --- Daemons -------------------------------------------------------
        // Five rows at most, chosen from the library. The heading opens it;
        // a click on a row opens its detail, drawn over this whole area.
        HudSection {
            id: daemonSection

            label: `DAEMONS${Appearance.separator}LOADED`
            katakana: "常駐"
            headingClickable: true
            onHeadingClicked: ShellState.openExclusive("daemons")

            // The rows and the label fade out while a detail is open, but the
            // section keeps its layout slot -- opacity, not visibility -- so the
            // label's position (where the daemon's name travels to) stays put
            // and the footer below it does not move.
            opacity: root.detailActive ? 0 : 1

            Behavior on opacity {
                NumberAnimation {
                    duration: root.detailActive ? Appearance.duration.exit : Appearance.duration.enter
                    easing.type: root.detailActive ? Easing.InCubic : Easing.OutCubic
                }
            }

            Column {
                id: daemonList

                width: parent.width
                spacing: 6

                Repeater {
                    model: Daemons.selectedEntries()

                    DaemonRow {
                        required property var modelData

                        entry: modelData
                        enabled: !root.detailActive
                    }
                }
            }
        }
    }

    // --- Footer ------------------------------------------------------------
    HudFooter {
        id: footer

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: root.padding

        opacity: root.detailActive ? 0 : 1
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.detailActive ? Appearance.duration.exit : Appearance.duration.enter
                easing.type: root.detailActive ? Easing.InCubic : Easing.OutCubic
            }
        }
    }

    // --- Daemon detail -----------------------------------------------------
    // Fills from the daemon label down to the HUD's bottom edge, over the rows
    // and the footer. The name is lifted here from its row (see travellingName);
    // BACK and Escape put it back.
    Item {
        id: detail

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        // The daemon label's own position, read reactively from the positioner
        // (mapToItem is a one-shot call and left this stuck at the top).
        y: column.y + daemonSection.y
        height: root.height - y - root.padding

        opacity: root.detailActive ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: root.detailActive ? Appearance.duration.enter : Appearance.duration.exit
                easing.type: root.detailActive ? Easing.OutCubic : Easing.InCubic
            }
        }

        // Where the clicked row sat below the label: the heading gap plus the
        // row's own place in the list. The name starts here and rises to 0.
        readonly property real rowOffset: 22 + Math.max(0, root.detailIndex) * 20
        property real nameRise: root.detailActive ? 0 : rowOffset

        Behavior on nameRise {
            NumberAnimation {
                duration: Appearance.duration.move
                easing.type: root.detailActive ? Easing.OutCubic : Easing.InCubic
            }
        }

        // The name, lifted from its row to the label's place, growing slightly
        // as it travels.
        Text {
            id: travellingName

            anchors.left: parent.left
            anchors.top: parent.top
            renderType: Text.NativeRendering
            text: root.detailEntry.name
            color: Theme.bright
            font.family: Appearance.font.display
            font.pixelSize: 16
            font.weight: Appearance.font.weightBold
            transformOrigin: Item.Left

            scale: root.detailActive ? 1 : 0.7

            Behavior on scale {
                NumberAnimation {
                    duration: Appearance.duration.move
                    easing.type: root.detailActive ? Easing.OutCubic : Easing.InCubic
                }
            }

            transform: Translate {
                y: detail.nameRise
            }
        }

        BackButton {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: -4
            // The terminal owns the deck's keyboard, so Escape does not reach
            // here; this is click-only.
            showKey: false

            onActivated: Daemons.expanded = ""
        }

        DaemonDetail {
            id: detailContent

            anchors.top: parent.top
            anchors.topMargin: 36
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            clip: true

            entry: root.detailEntry
        }
    }
}
