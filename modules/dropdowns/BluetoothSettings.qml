import QtQuick
import Quickshell.Bluetooth
import qs.components
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
        BackButton {
            onActivated: root.back()
        }

        // --- The adapter ----------------------------------------------------
        Column {
            width: parent.width
            spacing: 3

            Text {
                width: parent.width
                renderType: Text.NativeRendering
                text: root.hasAdapter ? root.adapter.name : "NO ADAPTER"
                color: root.powered ? Theme.bright : Theme.dim
                font.family: Appearance.font.display
                font.pixelSize: 16
                font.weight: Appearance.font.weightBold
                elide: Text.ElideRight
            }

            NrLabel {
                color: root.powered ? Theme.accent : Theme.dim
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
                    color: Theme.text
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
                    color: Theme.text
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
            height: Appearance.metrics.hairline
            color: Theme.hair
        }

        // --- Paired devices --------------------------------------------------
        NrLabel {
            color: Theme.bright
            text: `PAIRED DEVICES${Appearance.separator}${root.pairedDevices.length}`
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
                        color: pairedRow.modelData.connected ? Theme.bright : Theme.text
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
                        color: Theme.dim
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

                        color: pairedRow.confirming || forgetHover.hovered ? Theme.alert : Theme.dim
                        text: pairedRow.confirming ? "CONFIRM?" : "FORGET"

                        Behavior on color {
                            ColorAnimation {
                                duration: Appearance.duration.state
                                easing.type: Easing.OutCubic
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
                color: Theme.mute
                text: "NONE PAIRED"
            }
        }

        Rectangle {
            width: parent.width
            height: Appearance.metrics.hairline
            color: Theme.hair
        }

        // --- Scan for devices ------------------------------------------------
        Item {
            width: parent.width
            height: 20
            NrLabel {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.text
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
                        color: Theme.text
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
                color: Theme.mute
                text: (root.adapter?.discovering ?? false) ? "SCANNING..." : "SCAN TO FIND DEVICES"
            }
        }
    }
}
