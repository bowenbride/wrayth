import QtQuick
import qs.components
import qs.config
import qs.services

// The Wi-Fi settings view, shown in place of the network list. The connected
// network and its readings, the three switches NetworkManager keeps per
// connection, the saved networks with a quiet FORGET, and a way to join a
// hidden one. Everything here writes straight through the Wifi service.
Item {
    id: root

    property int buttonCut: 8
    signal back

    implicitHeight: col.implicitHeight

    readonly property int connectedSignal: {
        for (const network of Wifi.networks) {
            if (network.connected)
                return Math.round(network.signal);
        }
        return 0;
    }

    // A hidden-network join form, revealed by its button.
    property bool joining: false
    // The hidden network's name field takes the keyboard the moment JOIN
    // reveals it, a tick later so the revealed column is visible first.
    onJoiningChanged: if (joining) Qt.callLater(() => hiddenSsid.take())

    Column {
        id: col

        width: parent.width
        spacing: 14

        // --- Back -----------------------------------------------------------
        BackButton {
            onActivated: root.back()
        }

        // --- The connected network ------------------------------------------
        Column {
            width: parent.width
            spacing: 3

            Text {
                width: parent.width
                renderType: Text.NativeRendering
                text: Wifi.connected ? Demo.ssid(Wifi.activeSsid) : "NOT CONNECTED"
                color: Wifi.connected ? Theme.bright : Theme.dim
                font.family: Appearance.font.display
                font.pixelSize: 16
                font.weight: Appearance.font.weightBold
                elide: Text.ElideRight
            }

            NrLabel {
                color: Wifi.connected ? Theme.accent : Theme.dim
                text: Wifi.connected ? "LINKED" : "NO UPLINK"
            }
        }

        // --- SIGNAL / SECURITY / BAND ---------------------------------------
        Column {
            width: parent.width
            spacing: 6
            visible: Wifi.connected

            Item {
                width: parent.width
                height: 14
                NrLabel {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SIGNAL"
                }
                NrLabel {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    text: `${root.connectedSignal}%`
                }
            }

            Item {
                width: parent.width
                height: 14
                NrLabel {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "SECURITY"
                }
                NrLabel {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    text: Wifi.activeSecurity || "--"
                }
            }

            Item {
                width: parent.width
                height: 14
                NrLabel {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    text: "BAND"
                }
                NrLabel {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    text: Wifi.band || "--"
                }
            }
        }

        Rectangle {
            width: parent.width
            height: Appearance.metrics.hairline
            color: Theme.hair
        }

        // --- The three switches ---------------------------------------------
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
                    text: "AUTO-CONNECT"
                }
                ToggleButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    on: Wifi.autoconnect
                    usable: Wifi.connected
                    onToggled: Wifi.setAutoconnect(!Wifi.autoconnect)
                }
            }

            Item {
                width: parent.width
                height: 20
                NrLabel {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    text: "METERED"
                }
                ToggleButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    on: Wifi.metered
                    usable: Wifi.connected
                    onToggled: Wifi.setMetered(!Wifi.metered)
                }
            }

            Item {
                width: parent.width
                height: 20
                NrLabel {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.text
                    text: "RANDOM MAC"
                }
                ToggleButton {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    on: Wifi.randomMac
                    usable: Wifi.connected
                    onToggled: Wifi.setRandomMac(!Wifi.randomMac)
                }
            }
        }

        Rectangle {
            width: parent.width
            height: Appearance.metrics.hairline
            color: Theme.hair
        }

        // --- Saved networks --------------------------------------------------
        NrLabel {
            color: Theme.bright
            text: `SAVED NETWORKS${Appearance.separator}${Wifi.savedNames.length}`
        }

        Column {
            width: parent.width
            spacing: 2

            Repeater {
                model: Wifi.savedNames

                delegate: Item {
                    id: saved

                    required property string modelData
                    property bool confirming: false

                    width: parent.width
                    height: 22

                    NrLabel {
                        anchors.left: parent.left
                        anchors.right: forget.left
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.text
                        elide: Text.ElideRight
                        text: Demo.ssid(saved.modelData)
                    }

                    // Reserve the widest word so the name never shifts.
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

                        color: saved.confirming || forgetHover.hovered ? Theme.alert : Theme.dim
                        text: saved.confirming ? "CONFIRM?" : "FORGET"

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
                                if (saved.confirming) {
                                    Wifi.forget(saved.modelData);
                                    saved.confirming = false;
                                } else {
                                    saved.confirming = true;
                                    forgetTimeout.restart();
                                }
                            }
                        }

                        // A question left unanswered stands down.
                        Timer {
                            id: forgetTimeout
                            interval: 3000
                            onTriggered: saved.confirming = false
                        }
                    }
                }
            }

            NrLabel {
                visible: Wifi.savedNames.length === 0
                color: Theme.mute
                text: "NONE SAVED"
            }
        }

        // --- Join a hidden network ------------------------------------------
        ActionButton {
            width: parent.width
            visible: !root.joining
            text: "JOIN HIDDEN NETWORK"
            cutBottomLeft: root.buttonCut
            onClicked: root.joining = true
        }

        Column {
            width: parent.width
            spacing: 8
            visible: root.joining

            InputField {
                id: hiddenSsid
                width: parent.width
                placeholder: "NETWORK NAME"
                onAccepted: hiddenPass.take()
                onEscaped: root.joining = false
            }

            InputField {
                id: hiddenPass
                width: parent.width
                placeholder: "PASSWORD (IF ANY)"
                echoMode: TextInput.Password
                onAccepted: joinButton.clicked()
                onEscaped: root.joining = false
            }

            Row {
                width: parent.width
                spacing: 8

                ActionButton {
                    id: joinButton
                    text: "JOIN"
                    accented: true
                    usable: hiddenSsid.text.length > 0
                    cutBottomLeft: root.buttonCut
                    onClicked: {
                        Wifi.joinHidden(hiddenSsid.text, hiddenPass.text);
                        hiddenSsid.text = "";
                        hiddenPass.text = "";
                        root.joining = false;
                        root.back();
                    }
                }

                ActionButton {
                    text: "CANCEL"
                    onClicked: {
                        hiddenSsid.text = "";
                        hiddenPass.text = "";
                        root.joining = false;
                    }
                }
            }
        }
    }
}
