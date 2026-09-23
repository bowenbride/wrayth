import QtQuick
import Quickshell.Bluetooth
import Quickshell.Io
import qs.components
import qs.config
import qs.services
import qs.utils

DropdownFrame {
    id: root

    // A device row is two always-visible lines now: the name and state (34 px),
    // and under it the type, pairing and battery (18 px) -- so the battery reads
    // without opening anything. An open row gains its expansion (the quiet
    // FORGET and the full-width UNLINK) and the 14 px under it.
    readonly property int rowHeight: 34
    readonly property int secondLineHeight: 18
    readonly property int collapsedHeight: rowHeight + secondLineHeight
    readonly property int expansionHeight: 14 + 8 + 24

    // The address of the open device, or "". **One at a time**, so opening a
    // second row closes the first.
    property string open: ""

    // The settings view slides in over the list, the same as Wi-Fi's. BACK and
    // Escape reverse it; the frame's height eases to whichever view is showing.
    property bool showSettings: false
    readonly property bool canGoBack: showSettings
    function goBack(): void {
        root.showSettings = false;
    }

    readonly property int buttonCut: 8

    // The surface is sized to the taller of the two views, so switching never
    // reconfigures the layer mid-animation; only the visible panel grows and
    // shrinks within it. (The chrome is `implicitHeight - views.height`.)
    readonly property real surfaceHeight: implicitHeight - views.height + Math.max(listColumn.implicitHeight, settingsView.implicitHeight)

    // **The dropdown's own `visible` never changes.** The panel lives inside a
    // surface that is shown and hidden around it, so the frame is visible from
    // the moment it is built -- `onVisibleChanged` on it never fires, and the
    // reset that was hung on it never ran. `ShellState.dropdown` is what
    // actually opens and closes one.
    Connections {
        target: ShellState

        function onDropdownChanged(): void {
            if (ShellState.dropdown !== "bluetooth") {
                root.open = "";
                root.showSettings = false;
            }
        }
    }


    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var devices: {
        // Anything paired, plus anything discovery has turned up.
        const list = (Bluetooth.devices?.values ?? []).slice();
        list.sort((a, b) => {
            if (a.connected !== b.connected)
                return a.connected ? -1 : 1;
            if (a.paired !== b.paired)
                return a.paired ? -1 : 1;
            return a.name.localeCompare(b.name);
        });
        return list;
    }
    readonly property int pairedCount: devices.filter(device => device.paired).length
    readonly property int linkedCount: devices.filter(device => device.connected).length

    title: "LINK // BLUETOOTH"
    katakana: "近距離"

    // **No adapter is not the same as an adapter that is off.** With nothing
    // to talk to, both switches answered a press by doing nothing at all and
    // the empty list said `THE ADAPTER IS OFF`, which names a thing that is
    // not there.
    readonly property bool hasAdapter: root.adapter !== null

    headerRight: ToggleButton {
        on: root.adapter?.enabled ?? false
        usable: root.hasAdapter
        action: radioAction
        onToggled: {
            if (!root.adapter)
                return;
            radioAction.begin(root.adapter.enabled ? "DISABLING" : "ENABLING");
            root.adapter.enabled = !root.adapter.enabled;
        }
    }

    ActionState {
        id: radioAction
    }

    ActionState {
        id: discoveryAction
    }

    // The adapter reports back by changing the property that was asked for,
    // which is the only completion bluez offers here.
    Connections {
        target: root.adapter

        function onEnabledChanged(): void {
            if (radioAction.working)
                radioAction.succeed();
        }

        function onDiscoveringChanged(): void {
            if (discoveryAction.working)
                discoveryAction.succeed();
        }
    }

    // ========================================================================
    //  The two views, sliding past each other, the frame easing to fit.
    // ========================================================================
    Item {
        id: views

        width: parent.width
        height: root.showSettings ? settingsView.implicitHeight : listColumn.implicitHeight
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: Appearance.duration.panel
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: listView

            width: parent.width
            height: listColumn.implicitHeight
            opacity: root.showSettings ? 0 : 1
            visible: opacity > 0

            // The slide is a transform, not an `x`, so it never re-lays out.
            property real slide: root.showSettings ? -width : 0

            transform: Translate {
                x: listView.slide
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

            Column {
                id: listColumn

                width: parent.width
                // 14, the frame's own padding: every gap in this dropdown is the
                // same figure now, including the one under the last device block.
                spacing: root.padding

        // --- Status line ---------------------------------------------------
        Item {
            width: parent.width
            height: 20

            NrLabel {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: `${root.pairedCount} PAIRED // ${root.linkedCount} LINKED`
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                NrLabel {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "DISCOVERY"
                }

                ToggleButton {
                    anchors.verticalCenter: parent.verticalCenter
                    on: root.adapter?.discovering ?? false
                    usable: root.hasAdapter && (root.adapter?.enabled ?? false)
                    action: discoveryAction
                    onToggled: {
                        if (!root.adapter)
                            return;
                        discoveryAction.begin(root.adapter.discovering ? "STOPPING" : "SCANNING");
                        root.adapter.discovering = !root.adapter.discovering;
                    }
                }
            }
        }

        // --- Device list ---------------------------------------------------
        // **A row collapses to its name and opens on a click.** Every device
        // used to wear its whole block at once, so three paired devices filled
        // the dropdown while the network list showed eleven in the same space.
        // The two are one control in two services; this was the last place
        // they disagreed.
        ListView {
            id: list

            width: parent.width
            // About four two-line rows, then it scrolls -- plus whatever an open
            // row needs, so opening one does not push the others out of sight.
            height: Math.min(contentHeight, 4 * root.collapsedHeight + (root.open ? root.expansionHeight + 14 : 0))
            clip: true
            model: root.devices
            boundsBehavior: Flickable.StopAtBounds
            spacing: 0

            delegate: Item {
                id: row

                required property var modelData
                // Both are declared: asking for modelData puts the delegate in
                // required-properties mode, where the context `index` is no
                // longer visible. Demo mode's device masking numbers by it.
                required property int index
                readonly property bool linked: modelData.connected
                readonly property bool paired: modelData.paired
                readonly property bool expanded: root.open === modelData.address

                readonly property bool working: linkAction.working
                readonly property bool failedNow: linkAction.failed

                // `FORGET` destroys a pairing and cannot be undone from here,
                // so it asks. The question replaces the primary action's row
                // rather than opening anything, which is what keeps the
                // expansion the same height while it is up.
                property bool confirming: false

                onExpandedChanged: if (!expanded) confirming = false

                // The 8 px the expansion rises through as it fades in. A
                // transform, so nothing around it re-lays out.
                property real detailRise: Appearance.enterRise

                onDetailRiseChanged: {}

                Behavior on detailRise {
                    NumberAnimation {
                        duration: Appearance.duration.enter
                        easing.type: Easing.OutCubic
                    }
                }

                // One per row: unlike nmcli, bluez will happily link one device
                // while forgetting another.
                ActionState {
                    id: linkAction
                }

                ActionState {
                    id: forgetAction
                }

                Connections {
                    target: row.modelData

                    function onConnectedChanged(): void {
                        if (linkAction.working)
                            linkAction.succeed();
                    }

                    function onPairedChanged(): void {
                        if (forgetAction.working)
                            forgetAction.succeed();
                    }
                }

                width: list.width
                height: root.collapsedHeight + (expanded ? root.expansionHeight + 14 : 0)

                Rectangle {
                    anchors.fill: parent
                    color: row.linked ? Theme.alpha(Theme.accent, 0.06) : "transparent"
                }

                // 2 px accent left edge on the connected device, spanning both
                // always-visible lines.
                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    width: 2
                    height: root.collapsedHeight
                    color: Theme.accent
                    visible: row.linked
                }

                // --- The row itself ----------------------------------------
                Item {
                    id: line

                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    height: root.rowHeight

                    // The failure jolt, shared with every other clickable.
                    transform: [
                        Matrix4x4 {
                            property real skew: rowFeedback.shove * -4
                            matrix: Qt.matrix4x4(1, Math.tan(skew * Math.PI / 180), 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                        },
                        Translate {
                            x: rowFeedback.shove * 5
                        }
                    ]

                    BluetoothGlyph {
                        id: rune

                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: row.linked ? Theme.accent : row.paired ? Theme.signal : Theme.mute
                    }

                    Text {
                        anchors.left: rune.right
                        anchors.leftMargin: 8
                        anchors.right: state.left
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        // Masked for a recording; every action on this row
                        // still goes through `modelData.address`.
                        text: Demo.device(row.modelData.name, row.index)
                        textFormat: Text.PlainText
                        color: row.linked ? Theme.bright : Theme.text
                        font.family: Appearance.font.data
                        font.pixelSize: Appearance.size.body
                        elide: Text.ElideRight
                        maximumLineCount: 1
                        renderType: Text.NativeRendering
                    }

                    // **The row states its condition in plain text; the working
                    // animation belongs to the LINK/UNLINK button alone.** While
                    // a link runs it reads the verb (LINKING), with no sweep of
                    // its own -- one working indicator per action, on the control
                    // that was pressed.
                    NrLabel {
                        id: state

                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter

                        text: {
                            if (row.working)
                                return linkAction.verb;
                            if (row.linked)
                                return "LINKED";
                            return row.paired ? "PAIRED" : "FOUND";
                        }
                        color: {
                            if (row.linked)
                                return Theme.accent;
                            if (row.working)
                                return Theme.signal;
                            return Theme.dim;
                        }

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.duration.state
                                easing.type: Easing.OutCubic
                            }
                        }
                    }

                    // The row flashes on press -- that is the click on the row
                    // itself -- but carries no working sweep or failure jolt of
                    // its own; those are the button's.
                    Feedback {
                        id: rowFeedback

                        anchors.fill: parent
                        flashOpacity: 0.22
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: !row.working

                        onPressed: rowFeedback.flash()
                        onClicked: rowDefer.restart()
                    }

                    // One frame after the flash, so the acknowledgement is
                    // painted before anything else happens.
                    Timer {
                        id: rowDefer

                        interval: 16
                        onTriggered: root.open = row.expanded ? "" : row.modelData.address
                    }
                }

                // --- The always-visible second line ------------------------
                // **Type and pairing on the left, battery on the right, without
                // opening anything.** Colour does the dividing -- the type dim,
                // the state in the text colour, a space between them and no
                // slash. The battery reserves its widest state, so it never
                // shifts the line when the reading changes or a device without
                // a battery leaves the meter empty.
                Item {
                    id: secondLine

                    anchors.top: line.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 8
                    anchors.rightMargin: 8
                    height: root.secondLineHeight

                    Row {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        NrLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.dim
                            text: "AUDIO"
                        }

                        NrLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            color: Theme.text
                            text: row.paired ? "PAIRED" : "NOT PAIRED"
                        }
                    }

                    // Reserves "100%" so the meter and figure never move.
                    NrLabel {
                        id: batReserve

                        visible: false
                        text: "100%"
                    }

                    Row {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 6

                        SegmentMeter {
                            anchors.verticalCenter: parent.verticalCenter
                            // Opacity, not visibility, so its width is always
                            // reserved and the percentage beside it stays put.
                            opacity: row.modelData.batteryAvailable ? 1 : 0
                            segments: 5
                            segmentWidth: 4
                            segmentHeight: 8
                            value: row.modelData.battery
                            litColor: Theme.signal
                        }

                        NrLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            width: batReserve.implicitWidth
                            horizontalAlignment: Text.AlignRight
                            color: Theme.text
                            text: row.modelData.batteryAvailable ? Fmt.percent(row.modelData.battery * 100) : "--"
                        }
                    }

                    // The whole second line toggles the row too, so the battery
                    // is not a dead zone between two clickable halves.
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        enabled: !row.working
                        onPressed: rowFeedback.flash()
                        onClicked: rowDefer.restart()
                    }
                }

                // --- What the row opens into -------------------------------
                // **Nothing here happens on the row's own click.** Every one of
                // these is a button the user has to aim at.
                Column {
                    id: expansion

                    anchors.top: secondLine.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.leftMargin: 10
                    anchors.rightMargin: 8
                    spacing: 8

                    visible: opacity > 0
                    opacity: row.expanded ? 1 : 0

                    transform: Translate {
                        y: row.detailRise
                    }

                    Behavior on opacity {
                        NumberAnimation {
                            duration: row.expanded ? Appearance.duration.enter : Appearance.duration.exit
                            easing.type: row.expanded ? Easing.OutCubic : Easing.InCubic
                        }
                    }

                    onVisibleChanged: if (!visible) row.detailRise = Appearance.enterRise

                    // The quiet way out, on its own line now that the type and
                    // battery live on the always-visible second line above.
                    Item {
                        width: parent.width
                        height: 14

                        // The widest thing it can say, so the details beside
                        // it do not move when it starts working.
                        NrLabel {
                            id: forgetReserve

                            visible: false
                            text: "FORGETTING"
                        }

                        // **A word, not a button.** Unlinking is routine and
                        // undone by pressing the same button again; forgetting
                        // destroys a pairing and cannot be undone from here.
                        // Two same-sized bordered buttons side by side invited
                        // the same confidence in both. This one has no frame,
                        // no fill and no target beyond its own letters.
                        NrLabel {
                            id: forget

                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: forgetReserve.implicitWidth
                            horizontalAlignment: Text.AlignRight

                            visible: opacity > 0
                            opacity: row.paired && !row.confirming ? 1 : 0
                            color: forgetHover.hovered ? Theme.alert : Theme.dim
                            text: forgetAction.working ? "FORGETTING" : "FORGET"

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Appearance.duration.state
                                    easing.type: Easing.OutCubic
                                }
                            }

                            Behavior on color {
                                ColorAnimation {
                                    duration: Appearance.duration.state
                                    easing.type: Easing.OutCubic
                                }
                            }

                            HoverHandler {
                                id: forgetHover

                                enabled: row.paired && !row.confirming && !forgetAction.working
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                enabled: forgetHover.enabled
                                onTapped: row.confirming = true
                            }
                        }
                    }

                    // The primary action, or the question in its place.
                    Item {
                        width: parent.width
                        height: 24

                        ActionButton {
                            anchors.fill: parent
                            visible: opacity > 0
                            opacity: row.confirming ? 0 : 1

                            text: row.linked ? "UNLINK" : "LINK"
                            verbText: row.linked ? "UNLINKING" : "LINKING"
                            accented: true
                            action: linkAction

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Appearance.duration.state
                                    easing.type: Easing.OutCubic
                                }
                            }

                            onClicked: {
                                linkAction.begin(verbText);
                                if (row.linked)
                                    row.modelData.disconnect();
                                else
                                    row.modelData.connect();
                            }
                        }

                        Item {
                            anchors.fill: parent
                            visible: opacity > 0
                            opacity: row.confirming ? 1 : 0

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: Appearance.duration.state
                                    easing.type: Easing.OutCubic
                                }
                            }

                            NrLabel {
                                anchors.left: parent.left
                                anchors.right: answers.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.alert
                                elide: Text.ElideRight
                                // The device's name is on the line above this
                                // one; repeating it here cost most of the line
                                // and elided to `FORGET WH-1...`, which names
                                // nothing. The question is attached to its
                                // subject by being inside it.
                                text: "FORGET THIS DEVICE?"
                            }

                            Row {
                                id: answers

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                // **No verb and no action on the answer.** It
                                // dismisses the question the moment it is
                                // pressed, so it is never on screen while the
                                // work runs -- reserving the verb and the work
                                // block took the width the question needed.
                                ActionButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "FORGET"
                                    accented: true
                                    textColor: Theme.alert

                                    onClicked: {
                                        row.confirming = false;
                                        forgetAction.begin("FORGETTING");
                                        row.modelData.forget();
                                    }
                                }

                                ActionButton {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "KEEP"

                                    onClicked: row.confirming = false
                                }
                            }
                        }
                    }
                }
            }
        }

        // Nothing paired and nothing found is a state worth naming, rather
        // than a gap where a list would be.
        NrLabel {
            width: parent.width
            visible: root.devices.length === 0
            color: Theme.mute
            // Short enough to fit the panel. The first draft ran to "TURN
            // DISCOVERY ON TO FIND ONE" and elided at "TO FIN...", which is
            // worse than saying less.
            text: {
                if (!root.hasAdapter)
                    return "NO BLUETOOTH ADAPTER";
                return (root.adapter?.enabled ?? false) ? "NO DEVICES    TURN DISCOVERY ON" : "THE ADAPTER IS OFF";
            }
        }

        // --- Settings ------------------------------------------------------
        // On the panel's bottom edge, so its bottom-left corner is cut parallel
        // to the panel's own bottom-left chamfer. It no longer launches an
        // external manager: it switches to the in-place settings view.
        ActionButton {
            width: parent.width
            text: "BLUETOOTH SETTINGS"
            usable: root.hasAdapter
            cutBottomLeft: root.buttonCut
            onClicked: root.showSettings = true
        }
            }
        }

        // --- The settings view ----------------------------------------------
        BluetoothSettings {
            id: settingsView

            width: parent.width
            opacity: root.showSettings ? 1 : 0
            visible: opacity > 0

            buttonCut: root.buttonCut
            onBack: root.showSettings = false

            property real slide: root.showSettings ? 0 : width

            transform: Translate {
                x: settingsView.slide
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
        }
    }
}
