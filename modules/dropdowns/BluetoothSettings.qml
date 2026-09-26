import QtQuick
import Quickshell.Bluetooth
import qs.components
import qs.components.ui as UI
import qs.config
import qs.services
import qs.utils

// The Bluetooth settings view, shown in place of the device list. The adapter's
// own state, the discoverable and auto-connect switches, the paired devices
// with their battery and a confirming FORGET, and a scan that turns up nearby
// devices to pair with. Everything writes straight through BlueZ.
Item {
    id: root

    property int buttonCut: 8
    signal back

    implicitHeight: col.implicitHeight

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool hasAdapter: adapter !== null
    readonly property bool powered: adapter?.enabled ?? false

    readonly property var pairedDevices: (Bluetooth.devices?.values ?? []).filter(d => d.paired)
    readonly property var nearbyDevices: (Bluetooth.devices?.values ?? []).filter(d => !d.paired)

    // "Auto-connect known devices" maps to BlueZ's per-device Trusted flag: a
    // trusted device reconnects on its own. The switch is on when every paired
    // device is trusted, and toggling sets them all.
    readonly property bool autoConnect: pairedDevices.length > 0 && pairedDevices.every(d => d.trusted)

    function setAutoConnect(on: bool): void {
        for (const device of root.pairedDevices)
            device.trusted = on;
    }

    Column {
        id: col

        width: parent.width
        spacing: 14

        // --- Back -----------------------------------------------------------
        // The sub-view's title row: the quiet BackControl, then its Title.
        Row {
            spacing: Tokens.space.s8
            height: Tokens.measure.toggleHeight
            UI.BackControl {
                anchors.verticalCenter: parent.verticalCenter
                destination: "BLUETOOTH"
                onActivated: root.back()
            }
            UI.Title {
                anchors.verticalCenter: parent.verticalCenter
                text: "SETTINGS"
            }
        }

        // --- The adapter ----------------------------------------------------
        Column {
            width: parent.width
            spacing: 3

            Text {
                width: parent.width
                renderType: Text.NativeRendering
                text: root.hasAdapter ? root.adapter.name : "NO ADAPTER"
                color: root.powered ? Tokens.color.bright : Tokens.color.dim
                font.family: Tokens.font.display
                font.pixelSize: 16
                font.weight: Tokens.font.displayWeight
                elide: Text.ElideRight
            }

            NrLabel {
                color: root.powered ? Tokens.color.accent : Tokens.color.dim
                text: root.powered ? "POWERED" : "OFF"
            }
        }

        // --- The two switches -----------------------------------------------
        Column {
            width: parent.width
            spacing: 10

            Item {
                width: parent.width
                height: 20
                NrLabel {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tokens.color.text
                    text: "DISCOVERABLE"
                }
                ToggleButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    on: root.adapter?.discoverable ?? false
                    usable: root.powered
                    onToggled: {
                        if (root.adapter)
                            root.adapter.discoverable = !root.adapter.discoverable;
                    }
                }
            }

            Item {
                width: parent.width
                height: 20
                NrLabel {
                    anchors.left: parent.left
                    anchors.right: autoToggle.left
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    color: Tokens.color.text
                    elide: Text.ElideRight
                    text: "AUTO-CONNECT KNOWN DEVICES"
                }
                ToggleButton {
                    id: autoToggle
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    on: root.autoConnect
                    usable: root.pairedDevices.length > 0
                    onToggled: root.setAutoConnect(!root.autoConnect)
                }
            }
        }

        Rectangle {
            width: parent.width
            height: Tokens.measure.hairline
            color: Tokens.color.hair
        }

        // --- Paired devices --------------------------------------------------
        UI.SectionLabel {
            topPadding: 0
            text: `PAIRED DEVICES · ${root.pairedDevices.length}`
        }

        Column {
            width: parent.width
            spacing: 2

            Repeater {
                model: root.pairedDevices

                delegate: Item {
                    id: pairedRow

                    required property var modelData
                    required property int index
                    property bool confirming: false

                    width: parent.width
                    height: 24

                    NrLabel {
                        anchors.left: parent.left
                        anchors.right: battery.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: pairedRow.modelData.connected ? Tokens.color.bright : Tokens.color.text
                        elide: Text.ElideRight
                        text: Demo.device(pairedRow.modelData.name, pairedRow.index)
                    }

                    NrLabel {
                        id: battery

                        anchors.right: forget.left
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        width: batReserve.implicitWidth
                        horizontalAlignment: Text.AlignRight
                        color: Tokens.color.dim
                        text: pairedRow.modelData.batteryAvailable ? Fmt.percent(pairedRow.modelData.battery * 100) : "--"
                    }

                    NrLabel {
                        id: batReserve
                        visible: false
                        text: "100%"
                    }

                    NrLabel {
                        id: forgetReserve
                        visible: false
                        text: "CONFIRM?"
                    }

                    NrLabel {
                        id: forget

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        width: forgetReserve.implicitWidth
                        horizontalAlignment: Text.AlignRight

                        color: pairedRow.confirming || forgetHover.hovered ? Tokens.color.alert : Tokens.color.dim
                        text: pairedRow.confirming ? "CONFIRM?" : "FORGET"

                        Behavior on color {
                            ColorAnimation {
                                duration: Tokens.motion.feedback
                                easing.type: Easing.BezierSpline
                                easing.bezierCurve: Tokens.motion.easeIn
                            }
                        }

                        HoverHandler {
                            id: forgetHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: {
                                if (pairedRow.confirming) {
                                    pairedRow.modelData.forget();
                                    pairedRow.confirming = false;
                                } else {
                                    pairedRow.confirming = true;
                                    forgetTimeout.restart();
                                }
                            }
                        }

                        Timer {
                            id: forgetTimeout
                            interval: 3000
                            onTriggered: pairedRow.confirming = false
                        }
                    }
                }
            }

            NrLabel {
                visible: root.pairedDevices.length === 0
                color: Tokens.color.mute
                text: "NONE PAIRED"
            }
        }

        Rectangle {
            width: parent.width
            height: Tokens.measure.hairline
            color: Tokens.color.hair
        }

        // --- Scan for devices ------------------------------------------------
        Item {
            width: parent.width
            height: 20
            NrLabel {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: Tokens.color.text
                text: "SCAN FOR DEVICES"
            }
            ToggleButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                on: root.adapter?.discovering ?? false
                usable: root.powered
                onText: "ON"
                offText: "OFF"
                onToggled: {
                    if (root.adapter)
                        root.adapter.discovering = !root.adapter.discovering;
                }
            }
        }

        Column {
            width: parent.width
            spacing: 2

            Repeater {
                model: root.nearbyDevices

                delegate: Item {
                    id: nearbyRow

                    required property var modelData
                    required property int index

                    width: parent.width
                    height: 26

                    NrLabel {
                        anchors.left: parent.left
                        anchors.right: pairButton.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: Tokens.color.text
                        elide: Text.ElideRight
                        text: Demo.device(nearbyRow.modelData.name, nearbyRow.index)
                    }

                    ActionButton {
                        id: pairButton

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: nearbyRow.modelData.pairing ? "PAIRING" : "PAIR"
                        alsoText: ["PAIRING"]
                        accented: true
                        usable: !nearbyRow.modelData.pairing
                        onClicked: nearbyRow.modelData.pair()
                    }
                }
            }

            NrLabel {
                visible: root.nearbyDevices.length === 0
                color: Tokens.color.mute
                text: (root.adapter?.discovering ?? false) ? "SCANNING..." : "SCAN TO FIND DEVICES"
            }
        }
    }
}
