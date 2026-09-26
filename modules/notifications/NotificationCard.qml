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
            return Tokens.color.accent;
        if (low)
            return Tokens.color.mute;
        return Tokens.color.signal;
    }

    // The shell's own summary of what was held while you played.
    readonly property bool summaryCard: (notification?.hints?.["x-wrayth-internal"] ?? "") !== ""
    readonly property string tabText: critical ? "ALERT" : (low ? "LOG" : "INCOMING")
    readonly property string katakana: critical ? "警告" : (low ? "記録" : "着信")

    // Critical never times out; everything else gets the spec's six seconds.
    // A screenshot's card: the file it is about, from the shell's own hint.
    // It shows the thumbnail and OPEN, COPY and DELETE instead of VIEW.
    readonly property string shot: notification?.hints?.["x-wrayth-screenshot"] ?? ""
    // A recording's card: OPEN and DELETE (which confirms), no thumbnail.
    readonly property string video: notification?.hints?.["x-wrayth-recording"] ?? ""
    readonly property int lifetime: critical ? 0 : (shot !== "" || video !== "" ? 10000 : 6000)
    // DELETE asks first: the first press arms it, a second deletes, and it
    // stands down on its own after three seconds.
    property bool deleteArmed: false
    Timer {
        id: disarm
        interval: 3000
        onTriggered: root.deleteArmed = false
    }

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

    // DESIGN.md notification card: 12 x 14 px padding.
    readonly property real padding: Tokens.measure.dropdownPadding
    readonly property real vpadding: Tokens.space.s12
    // The category on the header line: CAPTURED for the shell's own
    // screenshots and recordings, else the level's word.
    readonly property string category: (shot !== "" || video !== "") ? "CAPTURED" : tabText

    signal dismissed

    chamfer: 0
    chamferTopLeft: 0
    chamferTopRight: Tokens.chamfer.cardTopRight
    chamferBottomRight: 0
    chamferBottomLeft: Tokens.chamfer.cardBottomLeft
    fillColor: Tokens.color.panel2
    borderColor: critical ? Tokens.color.accent : Tokens.color.hair

    implicitHeight: strip.height + body.implicitHeight + 2 * vpadding + Tokens.space.s8

    // --- Header line: category on the left, source on the right, 10 px -----
    Item {
        id: strip

        readonly property var role: Tokens.type.secondaryBody
        anchors.top: parent.top
        anchors.topMargin: root.vpadding
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        height: categoryText.implicitHeight

        Text {
            id: categoryText
            text: root.category
            // Critical in accent, low urgency quieter in dim, the rest signal.
            color: root.critical ? Tokens.color.accent : (root.low ? Tokens.color.dim : Tokens.color.signal)
            font.family: strip.role.family
            font.pixelSize: strip.role.size
            font.letterSpacing: strip.role.size * Tokens.type.hint.tracking
            renderType: Text.NativeRendering
        }
        Text {
            anchors.right: parent.right
            anchors.left: categoryText.right
            anchors.leftMargin: Tokens.space.s12
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: root.summaryCard ? "WRAYTH" : (root.notification?.appName || "UNKNOWN").toUpperCase()
            textFormat: Text.PlainText
            color: Tokens.color.dim
            font.family: strip.role.family
            font.pixelSize: strip.role.size
            font.letterSpacing: strip.role.size * Tokens.type.hint.tracking
            renderType: Text.NativeRendering
        }
    }

    Column {
        id: body

        anchors.top: strip.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        anchors.topMargin: Tokens.space.s8
        spacing: Tokens.space.s6

        Text {
            renderType: Text.NativeRendering
            width: parent.width

            // Title: 12 px, bright.
            text: root.notification?.summary ?? ""
            textFormat: Text.PlainText
            color: Tokens.color.bright
            elide: Text.ElideRight
            font.family: Tokens.font.data
            font.pixelSize: Tokens.type.rowName.size
        }

        Text {
            width: parent.width
            visible: text !== ""

            // Body: 10 px, dim. Plain text only.
            text: root.notification?.body ?? ""
            color: Tokens.color.dim
            font.family: Tokens.font.data
            font.pixelSize: Tokens.type.secondaryBody.size
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
        }

        // The screenshot itself, small, the full width of the card.
        Image {
            visible: root.shot !== ""
            width: parent.width
            // A fixed frame, the image fitted inside it: its own height is not
            // known until it has loaded, and the card must not jump when it is.
            height: visible ? 140 : 0
            source: root.shot !== "" ? `file://${root.shot}` : ""
            sourceSize.width: 744
            fillMode: Image.PreserveAspectFit
            horizontalAlignment: Image.AlignLeft
            asynchronous: true
            cache: false
        }

        // The meta line and the buttons share one row rather than stacking:
        // the card is wide and they were each using a line of their own.
        // A critical card never times out: it says so, in accent (a state
        // with a meaning, kept through the style pass).
        Text {
            visible: root.critical
            text: "PERSISTENT · ACK REQUIRED"
            color: Tokens.color.accent
            font.family: Tokens.type.hint.family
            font.pixelSize: Tokens.type.hint.size
            font.letterSpacing: Tokens.type.hint.size * Tokens.type.hint.tracking
            renderType: Text.NativeRendering
        }

        // Actions: equal-width secondary buttons, 24 px tall.
        Item {
            width: parent.width
            height: 24

            Row {
                id: buttons

                // The width each visible button gets.
                readonly property int shown: children.filter(c => c.visible).length
                readonly property real each: (width - Math.max(0, shown - 1) * spacing) / Math.max(1, shown)

                anchors.fill: parent
                spacing: Tokens.space.s8

                ActionButton {
                    width: buttons.each
                    height: 24
                    visible: root.shot !== ""
                    text: "OPEN"
                    onClicked: {
                        Screenshot.open(root.shot);
                        root.dismissed();
                    }
                }
                ActionButton {
                    width: buttons.each
                    height: 24
                    visible: root.shot !== ""
                    text: "COPY"
                    onClicked: Screenshot.copy(root.shot)
                }
                ActionButton {
                    width: buttons.each
                    height: 24
                    visible: root.shot !== ""
                    text: root.deleteArmed ? "CONFIRM" : "DELETE"
                    alsoText: ["CONFIRM", "DELETE"]
                    accented: root.deleteArmed
                    onClicked: {
                        if (!root.deleteArmed) {
                            root.deleteArmed = true;
                            disarm.restart();
                            return;
                        }
                        Screenshot.remove(root.shot);
                        root.dismissed();
                    }
                }

                ActionButton {
                    width: buttons.each
                    height: 24
                    visible: root.action !== null && root.shot === "" && root.video === ""
                    text: "VIEW"
                    // The app opens or raises its own window in answer, so
                    // the deck is closed first or a new one lands in it.
                    onClicked: {
                        Deck.leave();
                        root.action?.invoke();
                        root.dismissed();
                    }
                }

                ActionButton {
                    width: buttons.each
                    height: 24
                    visible: root.video !== ""
                    text: "OPEN"
                    onClicked: {
                        Recorder.open(root.video);
                        root.dismissed();
                    }
                }
                ActionButton {
                    width: buttons.each
                    height: 24
                    visible: root.video !== ""
                    text: root.deleteArmed ? "CONFIRM" : "DELETE"
                    alsoText: ["CONFIRM", "DELETE"]
                    accented: root.deleteArmed
                    onClicked: {
                        if (!root.deleteArmed) {
                            root.deleteArmed = true;
                            disarm.restart();
                            return;
                        }
                        Recorder.remove(root.video);
                        root.dismissed();
                    }
                }

                ActionButton {
                    width: buttons.each
                    height: 24
                    visible: root.shot === "" && root.video === ""
                    text: "DISMISS"
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
