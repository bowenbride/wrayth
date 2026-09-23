import QtQuick
import Quickshell.Services.Notifications
import qs.components
import qs.config
import qs.services

// One notification. The level decides the tab, the katakana, the frame and
// whether it times out at all.
ChamferPanel {
    id: root

    required property var notification

    readonly property string level: Notifications.levelOf(notification)
    readonly property bool critical: level === "CRITICAL"
    readonly property bool low: level === "LOW"

    readonly property color tone: {
        if (critical)
            return Theme.accent;
        if (low)
            return Theme.mute;
        return Theme.signal;
    }

    readonly property string tabText: critical ? "ALERT" : (low ? "LOG" : "INCOMING")
    readonly property string katakana: critical ? "警告" : (low ? "記録" : "着信")

    // Critical never times out; everything else gets the spec's six seconds.
    readonly property int lifetime: critical ? 0 : 6000

    // Whole seconds left, read off the drain bar's current width. Ceil so it
    // reads 6 for the whole of the first second and only shows 0 as the card
    // actually goes.
    readonly property int remainingSeconds: {
        if (lifetime <= 0)
            return 0;
        const full = drain.fullWidth;
        if (full <= 0)
            return Math.round(lifetime / 1000);
        return Math.ceil(drain.width / full * lifetime / 1000);
    }

    // The first action the notification offers, if any.
    readonly property var action: (notification?.actions ?? []).find(a => a.identifier !== "") ?? (notification?.actions ?? [])[0] ?? null

    readonly property real padding: 14

    signal dismissed

    chamfer: Appearance.chamfer.panel
    fillColor: Theme.panel2
    borderColor: critical ? Theme.accent : Theme.hair

    implicitHeight: strip.height + body.implicitHeight + padding + 2

    // --- Header strip ------------------------------------------------------
    Item {
        id: strip

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        height: 26

        SlantBlock {
            id: tab

            width: tabLabel.implicitWidth + 26
            height: parent.height
            fillColor: root.tone

            NrLabel {
                id: tabLabel

                anchors.left: parent.left
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                color: Theme.ground
                text: root.tabText
            }
        }

        // The app name is a label like any other: uppercase and tracked. Only
        // the sender's own name in the body and the message text are rendered
        // exactly as received.
        NrLabel {
            id: from

            anchors.left: tab.right
            anchors.leftMargin: 8
            anchors.right: kana.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: `FROM${Appearance.separator}${root.notification?.appName || "UNKNOWN"}`
        }

        Text {
            id: kana

            anchors.right: age.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter

            text: root.katakana
            color: root.tone
            font.family: Appearance.font.accent
            font.pixelSize: Appearance.size.katakana
            font.weight: Appearance.font.weightMedium
            renderType: Text.NativeRendering
        }

        NrLabel {
            id: age

            anchors.right: parent.right
            anchors.rightMargin: root.padding
            anchors.verticalCenter: parent.verticalCenter
            color: Theme.mute
            text: "NOW"
        }
    }

    // --- Body --------------------------------------------------------------
    Column {
        id: body

        anchors.top: strip.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin: root.padding * 0.7
        spacing: 6

        Text {
            renderType: Text.NativeRendering
            width: parent.width

            text: root.notification?.summary ?? ""
            textFormat: Text.PlainText
            color: Theme.bright
            elide: Text.ElideRight
            font.family: Appearance.font.data
            font.pixelSize: Appearance.size.body
            font.weight: Appearance.font.weightSemi
        }

        Text {
            width: parent.width
            visible: text !== ""

            text: root.notification?.body ?? ""
            color: Theme.text
            font.family: Appearance.font.data
            font.pixelSize: 12
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
        }

        // The meta line and the buttons share one row rather than stacking:
        // the card is wide and they were each using a line of their own.
        Item {
            width: parent.width
            height: Math.max(buttons.implicitHeight, meta.implicitHeight)

            NrLabel {
                id: meta

                anchors.left: parent.left
                anchors.right: buttons.left
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                color: root.critical ? Theme.accent : Theme.mute
                // Counts down with the bar rather than beside it. The figure
                // is derived from the bar's *animated* width, not from a timer
                // of its own, so the two can never drift apart and there is
                // only one thing keeping time -- the same rule the spectrum's
                // bars follow.
                text: root.critical ? `PERSISTENT${Appearance.separator}ACK REQUIRED` : `AUTO CLEAR${Appearance.separator}${root.remainingSeconds}S`
            }

            Row {
                id: buttons

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                ActionButton {
                    visible: root.action !== null
                    text: "VIEW"
                    accented: true
                    // The app opens or raises its own window in answer, so
                    // the deck is closed first or a new one lands in it.
                    onClicked: {
                        Deck.leave();
                        root.action?.invoke();
                        root.dismissed();
                    }
                }

                ActionButton {
                    text: "DISMISS"
                    textColor: Theme.dim
                    onClicked: root.dismissed()
                }
            }
        }
    }

    // --- Timer bar ---------------------------------------------------------
    // Drains along the bottom. A critical card never times out, so its bar just
    // stays full: the card is not going anywhere on its own.
    Rectangle {
        id: drain

        // Starts where the bottom-left cut ends, so the bar never runs out past
        // the chamfer and off the corner of the card.
        readonly property real start: root.chamferBottomLeft
        readonly property real fullWidth: root.width - start

        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.leftMargin: start
        height: 2
        width: root.width - start
        color: root.tone

        NumberAnimation on width {
            running: root.lifetime > 0
            from: drain.fullWidth
            to: 0
            duration: root.lifetime
            onFinished: root.dismissed()
        }
    }
}
