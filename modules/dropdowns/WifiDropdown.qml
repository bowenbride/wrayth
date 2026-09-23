import QtQuick
import Quickshell.Networking
import qs.components
import qs.config
import qs.services

DropdownFrame {
    id: root

    property string pending: ""

    // The settings view slides in over the list. Escape and BACK reverse it,
    // and the frame's height eases to whichever view is showing.
    property bool showSettings: false
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

    title: "UPLINK // WLAN"
    katakana: "無線"

    headerRight: ToggleButton {
        on: Networking.wifiEnabled
        action: radioAction
        onToggled: {
            radioAction.begin(Networking.wifiEnabled ? "DISABLING" : "ENABLING");
            Networking.wifiEnabled = !Networking.wifiEnabled;
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
                duration: Appearance.duration.panel
                easing.type: Easing.OutCubic
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
                spacing: root.padding

                // Status line.
                Item {
                    width: parent.width
                    height: 14

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
                                return Theme.accent;
                            if (Wifi.linking)
                                return Theme.signal;
                            return Theme.dim;
                        }
                        elide: Text.ElideRight
                        width: parent.width - 150
                    }

                    NrLabel {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.mute
                        text: Wifi.band ? `${Machine.wifiInterface} // ${Wifi.band}` : Machine.wifiInterface
                    }
                }

                // Network list.
                ListView {
                    id: list

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

                        property real detailRise: Appearance.enterRise

                        onExpandedChanged: detailRise = expanded ? 0 : detailRise

                        Behavior on detailRise {
                            NumberAnimation {
                                duration: Appearance.duration.enter
                                easing.type: Easing.OutCubic
                            }
                        }

                        width: list.width
                        height: 34 + (expanded ? expansion.implicitHeight + 14 : 0)

                        Rectangle {
                            anchors.fill: parent
                            color: netRow.isConnected ? Theme.alpha(Theme.accent, 0.06) : "transparent"
                        }

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            width: 2
                            height: 34
                            color: Theme.accent
                            visible: netRow.isConnected
                        }

                        Item {
                            id: line

                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 8
                            height: 34

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
                                litColor: netRow.isConnected ? Theme.accent : Theme.signal
                            }

                            Item {
                                id: lock

                                anchors.left: bars.right
                                anchors.leftMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                width: 7
                                height: 9
                                visible: netRow.secured

                                Rectangle {
                                    anchors.bottom: parent.bottom
                                    width: parent.width
                                    height: 5
                                    color: Theme.mute
                                }

                                Rectangle {
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    width: 5
                                    height: 5
                                    color: "transparent"
                                    border.width: 1
                                    border.color: Theme.mute
                                }
                            }

                            Text {
                                anchors.left: lock.right
                                anchors.leftMargin: netRow.secured ? 8 : 0
                                anchors.right: netState.left
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter

                                text: netRow.modelData.label
                                textFormat: Text.PlainText
                                color: netRow.isConnected ? Theme.bright : Theme.text
                                font.family: Appearance.font.data
                                font.pixelSize: Appearance.size.body
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
                                        return Theme.accent;
                                    if (netRow.working)
                                        return Theme.signal;
                                    return Theme.dim;
                                }
                                font.family: Appearance.font.data
                                font.pixelSize: Appearance.size.label
                                font.weight: Appearance.font.weightSemi
                                font.letterSpacing: Appearance.tracking(Appearance.size.label)
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
                                    duration: netRow.expanded ? Appearance.duration.enter : Appearance.duration.exit
                                    easing.type: netRow.expanded ? Easing.OutCubic : Easing.InCubic
                                }
                            }

                            onVisibleChanged: if (!visible) netRow.detailRise = Appearance.enterRise

                            NrLabel {
                                color: Theme.mute
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

                // Rescan.
                ActionButton {
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
