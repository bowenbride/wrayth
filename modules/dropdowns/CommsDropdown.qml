import QtQuick
import Quickshell.Hyprland
import qs.components
import qs.config
import qs.services
import qs.utils

// COMMS: the notification centre. Notification history grouped by app, Do Not
// Disturb, CLEAR ALL, and OPEN COMMS WORKSPACE (what clicking the indicator
// used to do). Opening it counts as looking: the indicator's dot clears.
//
// The history is in memory only -- the dropdown says so, because it is the
// thing a person would want to know before trusting it with a message.
DropdownFrame {
    id: root

    title: "COMMS"
    katakana: "通信"
    // Read by Dropdowns: this dropdown is 420 px wide.
    readonly property int panelWidth: 420

    readonly property int buttonCut: 8
    // Refreshed while open, for the ages; nothing ticks while it is closed.
    property real now: Date.now()

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.now = Date.now()
    }

    // What was unread when it opened keeps its accent edge while it is open;
    // everything else has the hairline. Opening it counts as looking.
    property var unread: ({})
    Component.onCompleted: {
        const u = {};
        for (const e of Notifications.history)
            if (!e.seen)
                u[e.key] = true;
        root.unread = u;
        Notifications.markSeen();
    }
    // Anything arriving while it is open is being looked at too.
    Connections {
        target: Notifications
        function onUnseenChanged(): void {
            Qt.callLater(Notifications.markSeen);
        }
    }

    // NOTIFY, or DO NOT DISTURB in the accent: 22 px.
    headerRight: Rectangle {
        implicitWidth: dndLabel.implicitWidth + 20
        implicitHeight: 22
        color: Notifications.dnd ? Theme.alpha(Theme.accent, 0.12) : "transparent"
        border.width: 1
        border.color: Notifications.dnd ? Theme.accent : Theme.hair

        Behavior on color {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }

        Text {
            id: dndLabel

            anchors.centerIn: parent
            text: Notifications.dnd ? "DO NOT DISTURB" : "NOTIFY"
            color: Notifications.dnd ? Theme.accent : Theme.dim
            font.family: Appearance.font.data
            font.pixelSize: 9
            font.weight: Appearance.font.weightSemi
            font.letterSpacing: 9 * 0.12
            renderType: Text.NativeRendering
        }
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: Notifications.dnd = !Notifications.dnd
        }
    }

    Column {
        width: parent.width
        spacing: 10

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

        // --- History ---------------------------------------------------------
        NrLabel {
            visible: Notifications.history.length === 0
            color: Theme.dim
            text: "NOTHING HERE YET"
        }

        Flickable {
            id: list

            visible: Notifications.history.length > 0
            width: parent.width
            height: Math.min(contentHeight, 340)
            contentHeight: groups.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: groups

                width: list.width - (scroll.visible ? 10 : 0)
                spacing: 0

                Repeater {
                    model: Notifications.groups

                    Column {
                        id: group

                        required property var modelData
                        required property int index

                        width: parent.width
                        spacing: 6
                        bottomPadding: 10

                        // Groups are separated by hairlines.
                        Rectangle {
                            width: parent.width
                            height: Appearance.metrics.hairline
                            color: Theme.hair
                        }

                        // The app: 10 px dim, 0.14em, its count on the right.
                        Item {
                            width: parent.width
                            height: 16

                            Text {
                                anchors.left: parent.left
                                anchors.right: count.left
                                anchors.rightMargin: 8
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: group.modelData.app.toUpperCase()
                                textFormat: Text.PlainText
                                color: Theme.dim
                                font.family: Appearance.font.data
                                font.pixelSize: 10
                                font.weight: Appearance.font.weightSemi
                                font.letterSpacing: 10 * 0.14
                                renderType: Text.NativeRendering
                            }
                            Text {
                                id: count

                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                text: `${group.modelData.entries.length}`
                                color: Theme.dim
                                font.family: Appearance.font.data
                                font.pixelSize: 10
                                renderType: Text.NativeRendering
                            }
                        }

                        Repeater {
                            model: group.modelData.entries.slice(0, 5)

                            // One notification: a 2 px left edge (the accent
                            // while unread, a hairline once seen), 8 px padding.
                            Item {
                                id: entry

                                required property var modelData

                                width: parent.width
                                height: lines.implicitHeight + 16

                                Rectangle {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.bottom: parent.bottom
                                    width: 2
                                    color: root.unread[entry.modelData.key] ? Theme.accent : Theme.hair
                                }

                                Column {
                                    id: lines

                                    anchors.left: parent.left
                                    anchors.leftMargin: 10
                                    anchors.right: parent.right
                                    anchors.rightMargin: 8
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 3

                                    Item {
                                        width: parent.width
                                        height: titleText.implicitHeight

                                        Text {
                                            id: titleText

                                            anchors.left: parent.left
                                            anchors.right: age.left
                                            anchors.rightMargin: 8
                                            text: entry.modelData.summary
                                            textFormat: Text.PlainText
                                            elide: Text.ElideRight
                                            color: Theme.text
                                            font.family: Appearance.font.data
                                            font.pixelSize: 11
                                            font.weight: Appearance.font.weightSemi
                                            renderType: Text.NativeRendering
                                        }
                                        Text {
                                            id: age

                                            anchors.right: parent.right
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: Fmt.age(entry.modelData.time, root.now)
                                            color: Theme.dim
                                            font.family: Appearance.font.data
                                            font.pixelSize: 9
                                            renderType: Text.NativeRendering
                                        }
                                    }
                                    Text {
                                        width: parent.width
                                        visible: text !== ""
                                        text: entry.modelData.body.replace(/\s+/g, " ")
                                        textFormat: Text.PlainText
                                        elide: Text.ElideRight
                                        color: Theme.dim
                                        font.family: Appearance.font.data
                                        font.pixelSize: 10
                                        renderType: Text.NativeRendering
                                    }
                                }
                            }
                        }

                        NrLabel {
                            visible: group.modelData.entries.length > 5
                            color: Theme.dim
                            text: `+${group.modelData.entries.length - 5} EARLIER`
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

        // CLEAR ALL on the left, what is kept on the right: both 9 px dim.
        Item {
            width: parent.width
            height: 14

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "CLEAR ALL"
                font.underline: true
                opacity: Notifications.history.length > 0 ? 1 : 0.5
                color: clearHover.hovered && Notifications.history.length > 0 ? Theme.text : Theme.dim
                font.family: Appearance.font.data
                font.pixelSize: 9
                font.letterSpacing: 9 * 0.12
                renderType: Text.NativeRendering

                HoverHandler {
                    id: clearHover
                    cursorShape: Notifications.history.length > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
                }
                TapHandler {
                    enabled: Notifications.history.length > 0
                    onTapped: Notifications.clearHistory()
                }
            }
            Text {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                text: "KEPT UNTIL LOGOUT, NEVER SAVED"
                color: Theme.dim
                font.family: Appearance.font.data
                font.pixelSize: 9
                font.letterSpacing: 9 * 0.12
                renderType: Text.NativeRendering
            }
        }

        // On the panel's bottom edge: the bottom-left cut. The accent frame,
        // an accent-tinted fill and accent text.
        ActionButton {
            width: parent.width
            height: 30
            text: "OPEN COMMS WORKSPACE"
            accented: true
            cutBottomLeft: root.buttonCut
            onClicked: {
                ShellState.closeDropdown("OPEN COMMS WORKSPACE");
                Hyprland.dispatch(`hl.dsp.workspace.toggle_special("communication")`);
            }
        }
    }
}
