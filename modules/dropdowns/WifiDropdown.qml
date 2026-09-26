import QtQuick
import Quickshell.Networking
import qs.components
import qs.components.ui as UI
import qs.config
import qs.services

DropdownFrame {
    id: root

    property string pending: ""

    // The settings view slides in over the list. Escape and BACK reverse it,
    // and the frame's height eases to whichever view is showing.
    property bool showSettings: false
    // A sub-view carries its own title row (BackControl + Title).
    showHeader: !showSettings
    // Read by Dropdowns so Escape goes back a step before it closes.
    readonly property bool canGoBack: showSettings
    function goBack(): void {
        root.showSettings = false;
    }

    // The bottom-left cut every popup's bottom-edge button carries, parallel to
    // the panel's own bottom-left chamfer.
    readonly property int buttonCut: 8

    // The surface is sized to the taller of the two views, so it never
    // reconfigures the layer mid-switch; only the visible panel animates its
    // height within it. (The chrome is `implicitHeight - views.height`.)
    readonly property real surfaceHeight: implicitHeight - views.height + Math.max(listColumn.implicitHeight, settingsView.implicitHeight)

    readonly property var open: {
        for (const network of Wifi.networks) {
            if (network.ssid === root.pending)
                return network;
        }
        return null;
    }

    readonly property bool needsPassphrase: !!open && open.secured && !open.known && !open.connected
    readonly property alias passphrase: input.text

    // **The field takes the keyboard as it appears, on the first click.** This
    // used to test `needsPassphrase` inside the handler -- but the handler runs
    // before that binding has re-evaluated for the new `pending`, so it read the
    // *previous* network's answer: false on a first click (no focus, typing
    // went nowhere), and the last network's true on a second one, which is why
    // only the second field ever took input. The decision now waits for the
    // bindings to settle, and is made again whenever the answer changes (a
    // rescan can turn a known network into one that needs a passphrase).
    onPendingChanged: {
        input.text = "";
        Wifi.clearError();
        Qt.callLater(root.focusPassphrase);
    }
    onNeedsPassphraseChanged: Qt.callLater(root.focusPassphrase)

    function focusPassphrase(): void {
        if (pending && needsPassphrase)
            input.forceActiveFocus();
    }

    function act(network: var): void {
        if (netAction.working || Wifi.linking)
            return;
        if (network.connected) {
            actionSsid = network.ssid;
            netAction.begin("UNLINKING");
            Wifi.disconnect();
            return;
        }
        if (network.secured && !network.known) {
            submit();
            return;
        }
        actionSsid = network.ssid;
        netAction.begin("LINKING");
        Wifi.connect(network.ssid);
    }

    function submit(): void {
        if (!pending || !passphrase || Wifi.linking)
            return;
        actionSsid = pending;
        netAction.begin("LINKING");
        Wifi.connectWithPsk(pending, passphrase);
    }

    property string actionSsid: ""

    ActionState {
        id: netAction
    }

    ActionState {
        id: scanAction
    }

    ActionState {
        id: radioAction
    }

    Connections {
        target: Wifi

        function onActionFinished(ok: bool, reason: string, detail: string): void {
            if (!netAction.working)
                return;
            if (ok)
                netAction.succeed();
            else
                netAction.fail(reason || "LINK FAILED", detail);
        }

        function onScanningChanged(): void {
            if (!Wifi.scanning && scanAction.working)
                scanAction.succeed();
        }

        function onRadioOnChanged(): void {
            if (radioAction.working)
                radioAction.succeed();
            if (!Wifi.radioOn && scanAction.working)
                scanAction.fail("RADIO OFF", "");
        }
    }

    Connections {
        target: Wifi

        function onLinkingChanged(): void {
            if (Wifi.linking || !root.pending)
                return;
            if (Wifi.error)
                input.clear();
            else
                root.pending = "";
        }
    }

    // Closing and reopening the dropdown starts on the list.
    Connections {
        target: ShellState

        function onDropdownChanged(): void {
            if (ShellState.dropdown !== "wifi")
                root.showSettings = false;
        }
    }

    title: "UPLINK"
    katakana: "回線"

    // One header control (DESIGN.md): Wi-Fi's ON / OFF. Airplane mode is the
    // quiet `flight` button on the status line; it turns every radio off
    // (Radio.qml), so this toggle waits it out.
    headerRight: Row {
        ToggleButton {
            height: 22
            on: Networking.wifiEnabled && !Radio.airplane
            usable: !Radio.airplane
            action: radioAction
            onToggled: {
                radioAction.begin(Networking.wifiEnabled ? "DISABLING" : "ENABLING");
                Networking.wifiEnabled = !Networking.wifiEnabled;
            }
        }
    }

    // ========================================================================
    //  The two views, sliding past each other, the frame easing to fit.
    // ========================================================================
    Item {
        id: views

        width: parent.width
        // The frame's height follows whichever view is showing, eased on the
        // panel scale so growing or shrinking never jumps or clips.
        height: root.showSettings ? settingsView.implicitHeight : listColumn.implicitHeight
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: Tokens.motion.panels
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeIn
            }
        }

        // The off-screen passphrase input, kept alive across rescans. Parked
        // here so it survives whichever view is up.
        TextInput {
            id: input

            width: 1
            height: 1
            opacity: 0
            echoMode: TextInput.Password
            activeFocusOnPress: false

            Keys.onReturnPressed: root.submit()
            Keys.onEnterPressed: root.submit()
        }

        // --- The list view --------------------------------------------------
        Item {
            id: listView

            width: parent.width
            height: listColumn.implicitHeight
            opacity: root.showSettings ? 0 : 1
            visible: opacity > 0

            // The slide is a transform, not an `x`, so it moves the painted
            // view without ever re-laying anything out.
            property real slide: root.showSettings ? -width : 0

            transform: Translate {
                x: listView.slide
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

            Column {
                id: listColumn

                width: parent.width
                spacing: root.padding

                // Airplane mode: the list gives way to one EmptyState line.
                UI.EmptyState {
                    width: parent.width
                    visible: Radio.airplane
                    text: "AIRPLANE MODE · ALL RADIOS OFF"
                }

                // Status line.
                Item {
                    width: parent.width
                    height: 14
                    visible: !Radio.airplane

                    NrLabel {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        text: {
                            if (Wifi.linking)
                                return `LINKING ${Demo.ssid(Wifi.linking).toUpperCase()}`;
                            if (Wifi.error)
                                return Wifi.error;
                            return `${Wifi.inRange} NETWORKS IN RANGE`;
                        }
                        color: {
                            if (Wifi.error)
                                return Tokens.color.accent;
                            if (Wifi.linking)
                                return Tokens.color.signal;
                            return Tokens.color.dim;
                        }
                        elide: Text.ElideRight
                        width: parent.width - 150
                    }

                    NrLabel {
                        anchors.right: airplane.left
                        anchors.rightMargin: Tokens.space.s8
                        anchors.verticalCenter: parent.verticalCenter
                        color: Tokens.color.dim
                        text: Wifi.band ? `${Machine.wifiInterface} · ${Wifi.band}` : Machine.wifiInterface
                    }
                    // Airplane mode: a quiet icon button, `dim`, `accent` while on.
                    Item {
                        id: airplane
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: Tokens.measure.muteButtonWidth
                        height: Tokens.measure.muteButtonHeight
                        Icon {
                            anchors.centerIn: parent
                            name: "flight"
                            size: Tokens.icon.inline
                            color: Radio.airplane ? Tokens.color.accent : (planeHover.hovered ? Tokens.color.text : Tokens.color.dim)
                        }
                        HoverHandler {
                            id: planeHover
                            cursorShape: Qt.PointingHandCursor
                        }
                        TapHandler {
                            onTapped: Radio.setAirplane(!Radio.airplane)
                        }
                    }
                }

                // Network list.
                ListView {
                    id: list

                    visible: !Radio.airplane
                    width: parent.width
                    height: Math.min(contentHeight, 7 * 34 + (root.pending ? 90 : 0))
                    clip: true
                    model: Wifi.networks
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: 0

                    delegate: Item {
                        id: netRow

                        required property var modelData
                        readonly property bool isConnected: modelData.connected
                        readonly property bool secured: modelData.secured
                        readonly property bool expanded: root.pending === modelData.ssid
                        readonly property bool owns: root.actionSsid === modelData.ssid
                        readonly property bool working: owns && netAction.working
                        readonly property bool failedNow: owns && netAction.failed

                        property real detailRise: Tokens.motion.rise

                        onExpandedChanged: detailRise = expanded ? 0 : detailRise

                        Behavior on detailRise {
                            NumberAnimation {
                                duration: Tokens.motion.panels
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Tokens.motion.easeIn
                            }
                        }

                        width: list.width
                        height: Tokens.measure.row + (expanded ? expansion.implicitHeight + 14 : 0)

                        Rectangle {
                            anchors.fill: parent
                            color: netRow.isConnected ? Tokens.color.rowSelected : "transparent"
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            width: 2
                            height: Tokens.measure.row
                            color: Tokens.color.accent
                            visible: netRow.isConnected
                        }

                        Item {
                            id: line

                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 8
                            height: Tokens.measure.row

                            transform: [
                                Matrix4x4 {
                                    property real skew: rowFeedback.shove * -4
                                    matrix: Qt.matrix4x4(1, Math.tan(skew * Math.PI / 180), 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
                                },
                                Translate {
                                    x: rowFeedback.shove * 5
                                }
                            ]

                            SignalBars {
                                id: bars

                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                strength: netRow.modelData.signal
                                litColor: Tokens.color.signal
                            }

                            // Secured: the font's `lock`, 14 px, dim.
                            Icon {
                                id: lock

                                anchors.left: bars.right
                                anchors.leftMargin: Tokens.space.s8
                                anchors.verticalCenter: parent.verticalCenter
                                visible: netRow.secured
                                name: "lock"
                                size: Tokens.icon.inline
                                color: Tokens.color.dim
                            }

                            Text {
                                anchors.left: lock.right
                                anchors.leftMargin: netRow.secured ? 8 : 0
                                anchors.right: netState.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter

                                text: netRow.modelData.label
                                textFormat: Text.PlainText
                                color: netRow.isConnected ? Tokens.color.bright : Tokens.color.text
                                font.family: Tokens.font.data
                                font.pixelSize: Tokens.type.rowName.size
                                elide: Text.ElideRight
                                maximumLineCount: 1
                                renderType: Text.NativeRendering
                            }

                            // **The row states its condition in plain text; the
                            // working animation belongs to the LINK/UNLINK button
                            // alone** -- one working indicator per action, on the
                            // control that was pressed. It reads the verb while a
                            // link runs, with no sweep of its own.
                            Text {
                                id: netState

                                renderType: Text.NativeRendering
                                anchors.right: parent.right
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter

                                text: {
                                    if (netRow.working)
                                        return netAction.verb;
                                    if (netRow.isConnected)
                                        return "LINKED";
                                    if (netRow.modelData.known)
                                        return "KNOWN";
                                    return netRow.secured ? "SECURED" : "OPEN";
                                }
                                color: {
                                    if (netRow.isConnected)
                                        return Tokens.color.accent;
                                    if (netRow.working)
                                        return Tokens.color.signal;
                                    return Tokens.color.dim;
                                }
                                font.family: Tokens.font.data
                                font.pixelSize: Tokens.type.rowMeta.size
                                font.weight: Tokens.font.dataWeight
                                font.letterSpacing: Tokens.type.rowMeta.size * Tokens.type.rowMeta.tracking
                                font.capitalization: Font.AllUppercase
                            }

                            // The row flashes on press; the working sweep and the
                            // failure jolt are the button's.
                            Feedback {
                                id: rowFeedback

                                anchors.fill: parent
                                flashOpacity: 0.22
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                enabled: !netAction.working

                                onPressed: rowFeedback.flash()
                                onClicked: rowDefer.restart()
                            }

                            Timer {
                                id: rowDefer

                                interval: 16
                                onTriggered: root.pending = netRow.expanded ? "" : netRow.modelData.ssid
                            }
                        }

                        Column {
                            id: expansion

                            anchors.top: line.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 10
                            anchors.rightMargin: 8
                            spacing: 8

                            visible: opacity > 0
                            opacity: netRow.expanded ? 1 : 0

                            transform: Translate {
                                y: netRow.detailRise
                            }

                            Behavior on opacity {
                                NumberAnimation {
                                    duration: netRow.expanded ? Tokens.motion.panels : Tokens.motion.panels
                                    easing.type: Easing.BezierSpline
                                    easing.bezierCurve: netRow.expanded ? Tokens.motion.easeIn : Tokens.motion.easeOut
                                }
                            }

                            onVisibleChanged: if (!visible) netRow.detailRise = Tokens.motion.rise

                            NrLabel {
                                color: Tokens.color.mute
                                text: {
                                    const parts = [`SIGNAL ${Math.round(netRow.modelData.signal)}%`];
                                    parts.push(netRow.secured ? "SECURED" : "OPEN");
                                    parts.push(netRow.modelData.known ? "SAVED" : "NOT SAVED");
                                    return parts.join("    ");
                                }
                            }

                            Item {
                                width: parent.width
                                height: 20
                                visible: netRow.secured && !netRow.modelData.known && !netRow.isConnected

                                PassphraseSlots {
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    slots: 12
                                    filled: Math.min(12, root.passphrase.length)
                                }
                            }

                            Row {
                                spacing: 8

                                ActionButton {
                                    text: netRow.isConnected ? "UNLINK" : "LINK"
                                    verbText: netRow.isConnected ? "UNLINKING" : "LINKING"
                                    action: root.actionSsid === netRow.modelData.ssid ? netAction : null
                                    accented: !netRow.isConnected
                                    usable: !netAction.working
                                    onClicked: root.act(netRow.modelData)
                                }

                                ActionButton {
                                    text: "FORGET"
                                    visible: netRow.modelData.known
                                    usable: !netAction.working
                                    // The row is cleared first: forgetting rebuilds the
                                    // network list, which destroys this delegate, and a
                                    // `root` read after that throws (it did, every time).
                                    onClicked: {
                                        const ssid = netRow.modelData.ssid;
                                        root.pending = "";
                                        Wifi.forget(ssid);
                                    }
                                }
                            }
                        }
                    }
                }

                // --- TUNNEL // VPN: NetworkManager's VPN connections ------------
                Column {
                    width: parent.width
                    spacing: 0

                    Rectangle {
                        width: parent.width
                        height: Tokens.measure.hairline
                        color: Tokens.color.hair
                    }
                    UI.SectionLabel {
                        bottomPadding: Tokens.space.s4
                        text: "TUNNEL · VPN"
                    }
                    // None configured: an EmptyState, and how to add one (secondary
                    // body, sentence case).
                    Column {
                        visible: Radio.vpns.length === 0
                        width: parent.width
                        spacing: Tokens.space.s4
                        bottomPadding: Tokens.space.s6
                        UI.EmptyState {
                            width: parent.width
                            implicitHeight: Tokens.measure.row
                            text: "NO VPNS SET UP"
                        }
                        Text {
                            readonly property var role: Tokens.type.secondaryBody
                            width: parent.width
                            horizontalAlignment: Text.AlignHCenter
                            elide: Text.ElideRight
                            text: "Add one in NetworkManager: nm-connection-editor, or import a .conf or .ovpn file."
                            color: Tokens.color.dim
                            font.family: role.family
                            font.pixelSize: role.size
                            renderType: Text.NativeRendering
                        }
                    }
                    Repeater {
                        model: Radio.vpns

                        Item {
                            id: vpnRow

                            required property var modelData

                            width: parent.width
                            height: Tokens.measure.row

                            Row {
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.right: vpnToggle.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8
                                clip: true

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: Math.min(implicitWidth, parent.width - vpnType.implicitWidth - 8)
                                    elide: Text.ElideRight
                                    text: vpnRow.modelData.name
                                    textFormat: Text.PlainText
                                    color: vpnRow.modelData.up ? Tokens.color.bright : Tokens.color.text
                                    font.family: Tokens.font.data
                                    font.pixelSize: 12
                                    renderType: Text.NativeRendering
                                }
                                Text {
                                    id: vpnType

                                    anchors.verticalCenter: parent.verticalCenter
                                    text: vpnRow.modelData.type
                                    color: Tokens.color.dim
                                    font.family: Tokens.font.data
                                    font.pixelSize: 10
                                    font.letterSpacing: 10 * 0.1
                                    renderType: Text.NativeRendering
                                }
                            }
                            ToggleButton {
                                id: vpnToggle

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 58
                                height: 22
                                on: vpnRow.modelData.up
                                onText: "UP"
                                offText: "DOWN"
                                usable: Radio.busy === "" && !Radio.airplane
                                onToggled: Radio.setVpn(vpnRow.modelData.name, !vpnRow.modelData.up)
                            }
                        }
                    }
                }

                // Rescan.
                ActionButton {
                    visible: !Radio.airplane
                    width: parent.width
                    text: "RESCAN NETWORKS"
                    verbText: "SCANNING"
                    action: scanAction
                    usable: Wifi.radioOn && !Wifi.scanning
                    onClicked: {
                        scanAction.begin("SCANNING");
                        Wifi.rescan();
                    }
                }

                // Into the settings view. On the panel's bottom edge, so its
                // bottom-left corner is cut to match the panel.
                ActionButton {
                    width: parent.width
                    text: "WI-FI SETTINGS"
                    cutBottomLeft: root.buttonCut
                    onClicked: root.showSettings = true
                }
            }
        }

        // --- The settings view ----------------------------------------------
        WifiSettings {
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
        }
    }
}
