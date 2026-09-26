import QtQuick
import Quickshell.Hyprland
import qs.components
import qs.components.ui as UI
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
    panelWidth: Tokens.measure.dropdownStandard

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
            color: Tokens.color.accent
            font.family: Tokens.font.data
            font.pixelSize: 9
            font.weight: Tokens.font.dataWeight
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
                color: Notifications.dnd ? Tokens.color.accent : (bellHover.hovered ? Tokens.color.text : Tokens.color.dim)
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
        color: Tokens.color.dim
        font.family: Tokens.font.data
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
                color: Tokens.color.accent
            }
            NrLabel {
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                color: Tokens.color.bright
                text: "UNREAD MESSAGES IN YOUR CHAT APP"
            }
        }

        // Empty: a calm ALL CLEAR.
        UI.EmptyState {
            width: parent.width
            visible: Notifications.history.length === 0
            text: "ALL CLEAR"
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

                        // The app's row: a TwoLineRow -- app and count on the meta
                        // line, the time on the right, the latest text below.
                        UI.TwoLineRow {
                            width: parent.width
                            meta: group.modelData.app.toUpperCase()
                            count: `${group.modelData.entries.length}`
                            metaRight: Fmt.age(group.latest.time, root.now)
                            text: group.latest.body ? `${group.latest.summary} · ${group.latest.body.replace(/\s+/g, " ")}` : group.latest.summary
                            unread: group.unread > 0
                            trailing: group.modelData.entries.length > 1 ? Tokens.measure.muteButtonWidth : 0
                            onClicked: {
                                ShellState.closeDropdown("a notification opened");
                                Notifications.open(group.latest);
                            }

                            // The rest of this app's notifications.
                            Item {
                                anchors.right: parent.right
                                anchors.rightMargin: Tokens.space.s4
                                anchors.verticalCenter: parent.verticalCenter
                                width: Tokens.measure.muteButtonWidth
                                height: Tokens.measure.muteButtonHeight
                                visible: group.modelData.entries.length > 1

                                Icon {
                                    anchors.centerIn: parent
                                    name: group.expanded ? "expand_more" : "chevron_right"
                                    size: Tokens.icon.chevron
                                    color: chevHover.hovered ? Tokens.color.text : Tokens.color.dim
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
                                    color: older.modelData.seen ? Tokens.color.dim : Tokens.color.text
                                    font.family: Tokens.font.data
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
            height: Tokens.measure.hairline
            color: Tokens.color.hair
        }

        // Footer: quiet controls, left and right.
        Item {
            width: parent.width
            height: Tokens.measure.buttonInline

            UI.Button {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                kind: "quiet"
                text: "CLEAR ALL"
                enabled: Notifications.history.length > 0
                onClicked: Notifications.clearHistory()
            }
            UI.Button {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                kind: "quiet"
                chevron: "right"
                text: "OPEN COMMS WORKSPACE"
                onClicked: {
                    ShellState.closeDropdown("OPEN COMMS WORKSPACE");
                    Hyprland.dispatch(`hl.dsp.workspace.toggle_special("communication")`);
                }
            }
        }
    }
}
