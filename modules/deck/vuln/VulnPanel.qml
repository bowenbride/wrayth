import QtQuick
import qs.components
import qs.config
import qs.services

// VULN WATCH: the bottom row's right panel.
ChamferPanel {
    id: root

    readonly property real padding: 14

    // Both top corners cut, both bottom corners square, so it interlocks with
    // the planner beside it. See the deck corner scheme.
    chamfer: Appearance.chamfer.panel
    chamferTopLeft: chamfer
    chamferBottomLeft: 0
    fillColor: Tokens.color.panel

    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.padding
        height: 18

        GlitchFx {
            group: "deck"
            id: headerFx

            key: "panel:vuln"
            textual: true
            fills: true
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: headerRow.implicitWidth
            height: headerRow.implicitHeight
            scrambleItems: [vulnTitle]

        Row {
            id: headerRow

            anchors.fill: parent
            spacing: 8

            NrLabel {
                id: vulnTitle

                anchors.verticalCenter: parent.verticalCenter
                color: Tokens.color.bright
                text: "VULN WATCH"
            }

            KanaTag {
                anchors.verticalCenter: parent.verticalCenter
                text: "脆弱性"
                title: vulnTitle
            }
        }
        }
    }

    // --- The count ---------------------------------------------------------
    Item {
        id: tally

        anchors.top: header.bottom
        anchors.topMargin: 6
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        height: 48

        // **The count, and it is a number.** A sweep that changes it fires a
        // glitch here; the glitch may split it and slice it and may never
        // scramble it, because this is exactly the figure the panel exists to
        // report.
        GlitchFx {
            group: "deck"
            id: countFx

            key: "vuln"
            numeric: true
            fills: true

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            // **Three digits, always.** The line beside it is anchored to this
            // edge, so sizing the slot to the figure moved `PACKAGES AFFECTED`
            // and the `arch-audit // SYNCED` line every time the count changed.
            width: Math.max(count.implicitWidth, countReserve.advanceWidth)
            height: count.implicitHeight

        Text {
            renderType: Text.NativeRendering
            id: count

            anchors.fill: parent

            // **`--`, not `0`, when arch-audit never ran.** An audit that
            // could not run found nothing in the same sense that an unopened
            // letter contains no bad news, and a big confident zero here is
            // the most reassuring thing on the deck.
            text: Vuln.available ? Vuln.count : "--"
            color: Vuln.available ? Tokens.color.accent : Tokens.color.mute
            font.family: Tokens.font.display
            font.pixelSize: 44
            font.weight: Tokens.font.displayWeight
        }

        TextMetrics {
            id: countReserve

            font: count.font
            text: "000"
        }
        }

        Column {
            anchors.left: countFx.right
            anchors.leftMargin: 12
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 3

            NrLabel {
                width: parent.width
                color: Tokens.color.text
                text: "PACKAGES AFFECTED"
            }

            Row {
                width: parent.width
                spacing: 8

                NrLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width - sweep.width - 8)
                    color: Tokens.color.mute
                    elide: Text.ElideRight
                    // The daemon name keeps its own case, as in the HUD.
                    font.capitalization: Font.MixedCase
                    text: {
                        if (!Vuln.available)
                            return "arch-audit · NOT INSTALLED";
                        return Vuln.synced ? `arch-audit · SYNCED ${Vuln.syncedMinutes} MIN AGO` : "arch-audit · SYNCING";
                    }
                }

                // Re-runs the audit on demand. It fetches the security tracker
                // over the network, so it wears the working state rather than
                // looking like nothing happened.
                ActionButton {
                    id: sweep

                    anchors.verticalCenter: parent.verticalCenter

                    text: "SWEEP"
                    verbText: "SWEEPING"
                    action: sweepAction
                    // Nothing to sweep with. Without this the button began a
                    // working state that only the 20 s timeout could end.
                    usable: Vuln.available
                    onClicked: {
                        sweepAction.begin("SWEEPING");
                        Vuln.refresh();
                    }
                }
            }
        }
    }

    // The audit fetches the security tracker over the network, so it takes
    // seconds rather than milliseconds.
    ActionState {
        id: sweepAction
    }

    Connections {
        target: Vuln

        function onPackagesChanged(): void {
            if (sweepAction.working)
                sweepAction.succeed();
        }

        // **`packages` is not guaranteed to change.** A sweep that finds
        // exactly what the last one did still ends, and the button has to end
        // with it rather than run to the timeout. `scanning` falling to false
        // is the scan being over, whatever it found -- and it now falls even
        // when the tool could not be started.
        function onScanningChanged(): void {
            if (!Vuln.scanning && sweepAction.working)
                sweepAction.succeed();
        }

        // The count changing after a sweep is the panel's own news, and it is
        // the only thing on the deck that changes without the user doing
        // something to it.
        function onCountChanged(): void {
            Glitch.fire("vuln", null);
        }
    }

    // --- The hover tag -----------------------------------------------------
    // A greyed button explains itself here rather than inside its own row,
    // which clips. Anchored just above the row it belongs to; it does not
    // follow the cursor.
    property string tagText: ""
    property real tagX: 0
    property real tagY: 0

    function showTag(text: string, anchorItem: Item): void {
        const at = anchorItem.mapToItem(root, 0, 0);
        tagX = Math.max(root.padding, Math.min(at.x + anchorItem.width - tag.implicitWidth, root.width - root.padding - tag.implicitWidth));
        tagY = at.y - tag.implicitHeight - 3;
        tagText = text;
    }

    function hideTag(): void {
        tagText = "";
    }

    // --- Severity ----------------------------------------------------------
    Row {
        id: severities

        anchors.top: tally.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        spacing: 8

        readonly property real cellWidth: (width - spacing * 2) / 3

        SeverityCell {
            width: severities.cellWidth
            label: "HIGH"
            count: Vuln.high
            tone: Tokens.color.accent
            filled: true
        }

        SeverityCell {
            width: severities.cellWidth
            label: "MED"
            count: Vuln.medium
            tone: Tokens.color.alert
        }

        SeverityCell {
            width: severities.cellWidth
            label: "LOW"
            count: Vuln.low
            tone: Tokens.color.dim
        }
    }

    // --- Affected packages -------------------------------------------------
    // Grouped by what can be done about them rather than repeating a status on
    // every row: FIX READY first, because it is the section that can be acted
    // on. The list scrolls, and the overflow line says how much is below the
    // fold so a partly visible row never reads as the end of the list.
    Item {
        id: list

        anchors.top: severities.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.bottomMargin: root.padding

        readonly property int rowHeight: 20
        // The header is a row like any other. Everything in the list sits on a
        // single `rowHeight` grid -- headers, rows, and an open row's detail --
        // which is what makes "only whole rows" possible at all: with a header
        // of its own size, no viewport height and no scroll position could
        // guarantee the last visible row was not cut in half.
        readonly property int headerHeight: rowHeight
        // Only one row is ever open, so the panel does not turn into a wall of
        // CVE numbers.
        property string expandedName: ""

        // How much is still below the fold, in rows. Measured off the
        // Flickable rather than by walking the sections: a hand-rolled walk had
        // to re-derive the header heights and the open row's extra height, and
        // drifted out of step with what was actually laid out. This cannot
        // disagree with the scroll position, and reaches zero at the bottom.
        readonly property int below: {
            const hidden = flick.contentHeight - (flick.contentY + flick.height);
            return hidden > 1 ? Math.ceil(hidden / rowHeight) : 0;
        }

        Flickable {
            id: flick

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            // A whole number of rows, so the bottom of the viewport always
            // falls on a row boundary and the last one visible is never cut.
            // The row below is reserved for the overflow line -- constant
            // rather than conditional on `below`, which is computed from this
            // height and would be a binding loop.
            height: Math.max(0, Math.floor((list.height - list.rowHeight) / list.rowHeight) * list.rowHeight)
            contentWidth: width
            contentHeight: groups.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            // Settle on a row boundary, so a flick cannot leave a row half cut
            // at the top or the bottom.
            function snap(): void {
                const limit = Math.max(0, contentHeight - height);
                contentY = Math.min(limit, Math.round(contentY / list.rowHeight) * list.rowHeight);
            }

            onMovementEnded: snap()
            onFlickEnded: snap()

            Column {
                id: groups

                width: flick.width

                Repeater {
                    model: [
                        {
                            title: "FIX READY",
                            entries: Vuln.fixReady
                        },
                        {
                            title: "AWAITING UPSTREAM",
                            entries: Vuln.awaiting
                        }
                    ]

                    Column {
                        id: section

                        required property var modelData

                        width: groups.width
                        visible: modelData.entries.length > 0

                        Item {
                            width: parent.width
                            height: list.headerHeight

                            NrLabel {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.verticalCenterOffset: 2
                                color: section.modelData.title === "FIX READY" ? Tokens.color.signal : Tokens.color.mute
                                text: `${section.modelData.title} · ${section.modelData.entries.length}`
                            }

                            // The hairline that separates a section from the
                            // one above it, as everywhere else in the shell.
                            Rectangle {
                                anchors.bottom: parent.bottom
                                anchors.left: parent.left
                                anchors.right: parent.right
                                height: Tokens.measure.hairline
                                color: Tokens.color.hair
                            }
                        }

                        Repeater {
                            model: section.modelData.entries

                            PackageRow {
                                required property var modelData

                                width: groups.width
                                entry: modelData
                                expanded: list.expandedName === modelData.name

                                onToggled: list.expandedName = expanded ? "" : modelData.name

                                // The row clips, so a tag anchored inside it
                                // would be cut off. The panel draws it instead,
                                // over the list, at the row's own position.
                                onExplain: (text, anchorItem) => root.showTag(text, anchorItem)
                                onExplainCleared: root.hideTag()
                            }
                        }
                    }
                }
            }
        }

        // TEMPORARY (QA): rows are click-to-expand and `ydotoold` is not
        // running, so this is how the frame bursts reach them. Remove with the
        // `qa` IPC handler.
        Connections {
            target: ShellState

            function onQaAction(kind: string): void {
                if (kind === "expand")
                    list.expandedName = Vuln.packages.length ? Vuln.packages[0].name : "";
                else if (kind === "scroll")
                    flick.contentY = Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + 70);
                else if (kind === "collapse")
                    list.expandedName = "";
                else if (kind === "fixready") {
                    // A synthetic upgradable package, so the FIX READY section
                    // and its UPDATE button can be photographed. Nothing on
                    // this machine is upgradable at the moment.
                    const fake = {
                        name: "openssl",
                        severity: "HIGH",
                        fixed: true,
                        fixedVersion: "3.5.4-1",
                        type: "arbitrary code execution",
                        shortType: "CODE EXEC",
                        cves: ["CVE-2022-2068", "CVE-2025-4575"],
                        cveCount: 2,
                        group: "FIX READY"
                    };
                    Vuln.packages = [fake].concat(Vuln.packages.filter(entry => entry.name !== "openssl"));
                }
            }
        }

        // Sits over the bottom of the list rather than taking a row from it, so
        // scrolling can still reach what it is counting.
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: list.rowHeight
            visible: list.below > 0
            color: Tokens.color.panel

            NrLabel {
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                color: Tokens.color.mute
                text: `+${list.below} MORE`
            }
        }
    }

    // Drawn last, so it sits over the list rather than under it.
    Rectangle {
        id: tag

        x: root.tagX
        y: root.tagY
        implicitWidth: tagLabel.implicitWidth + 12
        implicitHeight: 18
        width: implicitWidth
        height: implicitHeight

        visible: opacity > 0
        opacity: root.tagText !== "" ? 1 : 0
        color: Tokens.color.panelHex

        Behavior on opacity {
            NumberAnimation {
                duration: root.tagText !== "" ? Tokens.motion.panels : Tokens.motion.panels
                easing.type: Easing.BezierSpline
                easing.bezierCurve: root.tagText !== "" ? Tokens.motion.easeIn : Tokens.motion.easeOut
            }
        }
        border.width: Tokens.measure.hairline
        border.color: Tokens.color.hair

        NrLabel {
            id: tagLabel

            anchors.centerIn: parent
            centred: true
            color: Tokens.color.mute
            text: root.tagText
        }
    }

}
