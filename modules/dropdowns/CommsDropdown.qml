import QtQuick
import Quickshell.Hyprland
import qs.components
import qs.config
import qs.services
import qs.utils

// COMMS: one row per app, its latest notification underneath, unread ones
// marked; a chevron shows the rest. Clicking a notification opens it (its
// default action, else the app's window) and takes it off the list. Reading
// in the app clears it too: see Notifications.qml. Do Not Disturb is the bell.
DropdownFrame {
    id: root

    title: "COMMS"
    katakana: "通信"
    // Read by Dropdowns: this dropdown is 420 px wide.
    readonly property int panelWidth: 420

    // Refreshed while open, for the ages; nothing ticks while it is closed.
    property real now: Date.now()
    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    // Which apps are expanded to show all their notifications.
    property var open: ({})

    // Do Not Disturb: a quiet bell; crossed out and labelled in the accent
    // only while on.
    headerRight: Row {
        spacing: 6

        Text {
            anchors.verticalCenter: parent.verticalCenter
            visible: Notifications.dnd
            text: "DO NOT DISTURB"
            color: Theme.accent
            font.family: Appearance.font.data
            font.pixelSize: 9
            font.weight: Appearance.font.weightSemi
            font.letterSpacing: 9 * 0.14
            renderType: Text.NativeRendering
        }
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: 22
            height: 22
            Icon {
                anchors.centerIn: parent
                name: Notifications.dnd ? "notifications_off" : "notifications"
                size: 16
                color: Notifications.dnd ? Theme.accent : (bellHover.hovered ? Theme.text : Theme.dim)
            }
            HoverHandler {
                id: bellHover
                cursorShape: Qt.PointingHandCursor
            }
            TapHandler {
                onTapped: Notifications.dnd = !Notifications.dnd
            }
        }
    }

    component Small: Text {
        color: Theme.dim
        font.family: Appearance.font.data
        font.pixelSize: 9
        font.letterSpacing: 9 * 0.14
        renderType: Text.NativeRendering
    }

    Column {
        width: parent.width
        spacing: 8

        // A message waiting in the chat client: the other half of the dot.
        Item {
            width: parent.width
            height: 18
            visible: Messages.unread

            Rectangle {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 6
                height: 6
                color: Theme.accent
            }
            NrLabel {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.bright
                text: "UNREAD MESSAGES IN YOUR CHAT APP"
            }
        }

        // Empty: a calm ALL CLEAR.
        Item {
            width: parent.width
            height: 60
            visible: Notifications.history.length === 0
            Small {
                anchors.centerIn: parent
                text: "ALL CLEAR"
                font.pixelSize: 10
            }
        }

        Flickable {
            id: list

            visible: Notifications.history.length > 0
            width: parent.width
            height: Math.min(contentHeight, 360)
            contentHeight: apps.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: apps

                width: list.width - (scroll.visible ? 10 : 0)
                spacing: 2

                Repeater {
                    model: Notifications.groups

                    Column {
                        id: group

                        required property var modelData
                        readonly property var latest: modelData.entries[0]
                        readonly property int unread: modelData.entries.filter(e => !e.seen).length
                        readonly property bool expanded: !!root.open[modelData.app]

                        width: parent.width

                        // The app's row: the latest notification.
                        Item {
                            width: parent.width
                            height: 44

                            Rectangle {
                                anchors.fill: parent
                                color: rowHover.hovered ? Theme.cell : "transparent"
                            }
                            Rectangle {
                                width: 2
                                height: parent.height
                                color: Theme.accent
                                visible: group.unread > 0
                            }

                            Row {
                                x: 10
                                y: 7
                                spacing: 6
                                Small {
                                    text: group.modelData.app.toUpperCase()
                                }
                                Small {
                                    text: `${group.modelData.entries.length}`
                                    color: group.unread > 0 ? Theme.accent : Theme.dim
                                }
                            }
                            Small {
                                anchors.right: chevron.left
                                anchors.rightMargin: 4
                                y: 7
                                text: Fmt.age(group.latest.time, root.now)
                            }
                            Text {
                                x: 10
                                y: 22
                                width: parent.width - 10 - 34
                                elide: Text.ElideRight
                                text: group.latest.body ? `${group.latest.summary} · ${group.latest.body.replace(/\s+/g, " ")}` : group.latest.summary
                                textFormat: Text.PlainText
                                color: group.latest.seen ? Theme.text : Theme.bright
                                font.family: Appearance.font.data
                                font.pixelSize: 11
                                renderType: Text.NativeRendering
                            }
                            HoverHandler {
                                id: rowHover
                                cursorShape: Qt.PointingHandCursor
                            }
                            TapHandler {
                                onTapped: {
                                    ShellState.closeDropdown("a notification opened");
                                    Notifications.open(group.latest);
                                }
                            }

                            // The rest of this app's notifications.
                            Item {
                                id: chevron

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                width: 24
                                height: 24
                                visible: group.modelData.entries.length > 1

                                Icon {
                                    anchors.centerIn: parent
                                    name: group.expanded ? "expand_more" : "chevron_right"
                                    size: 16
                                    color: chevHover.hovered ? Theme.text : Theme.dim
                                }
                                HoverHandler {
                                    id: chevHover
                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler {
                                    onTapped: {
                                        const next = Object.assign({}, root.open);
                                        next[group.modelData.app] = !group.expanded;
                                        root.open = next;
                                    }
                                }
                            }
                        }

                        // Expanded: the others, one 10 px line each with its time.
                        Repeater {
                            model: group.expanded ? group.modelData.entries.slice(1, 12) : []

                            Item {
                                id: older

                                required property var modelData

                                width: group.width
                                height: 20

                                Rectangle {
                                    anchors.fill: parent
                                    color: olderHover.hovered ? Theme.cell : "transparent"
                                }
                                Text {
                                    x: 22
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width - 22 - 44
                                    elide: Text.ElideRight
                                    text: older.modelData.body ? `${older.modelData.summary} · ${older.modelData.body.replace(/\s+/g, " ")}` : older.modelData.summary
                                    textFormat: Text.PlainText
                                    color: older.modelData.seen ? Theme.dim : Theme.text
                                    font.family: Appearance.font.data
                                    font.pixelSize: 10
                                    renderType: Text.NativeRendering
                                }
                                Small {
                                    anchors.right: parent.right
                                    anchors.rightMargin: 28
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: Fmt.age(older.modelData.time, root.now)
                                }
                                HoverHandler {
                                    id: olderHover
                                    cursorShape: Qt.PointingHandCursor
                                }
                                TapHandler {
                                    onTapped: {
                                        ShellState.closeDropdown("a notification opened");
                                        Notifications.open(older.modelData);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            ShellScrollBar {
                id: scroll

                parent: list.parent
                x: list.x + list.width - width
                y: list.y
                height: list.height
                view: list
            }
        }

        Rectangle {
            width: parent.width
            height: Appearance.metrics.hairline
            color: Theme.hair
        }

        // Quiet controls: CLEAR ALL, and OPEN COMMS WORKSPACE with a chevron.
        Item {
            width: parent.width
            height: 22

            Small {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "CLEAR ALL"
                opacity: Notifications.history.length > 0 ? 1 : 0.5
                color: clearHover.hovered && Notifications.history.length > 0 ? Theme.text : Theme.dim
                HoverHandler {
                    id: clearHover
                    cursorShape: Notifications.history.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
                TapHandler {
                    enabled: Notifications.history.length > 0
                    onTapped: Notifications.clearHistory()
                }
            }
            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 0
                Small {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "OPEN COMMS WORKSPACE"
                    color: wsHover.hovered ? Theme.text : Theme.dim
                }
                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "chevron_right"
                    size: 16
                    color: wsHover.hovered ? Theme.text : Theme.dim
                }
                HoverHandler {
                    id: wsHover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onTapped: {
                        ShellState.closeDropdown("OPEN COMMS WORKSPACE");
                        Hyprland.dispatch(`hl.dsp.workspace.toggle_special("communication")`);
                    }
                }
            }
        }
    }
}
