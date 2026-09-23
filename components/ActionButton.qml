import QtQuick
import qs.config

// A bordered text button: RESCAN NETWORKS, LINK, FORGET, BLUETOOTH SETTINGS.
//
// Every state in the design system's interaction set is here, so a caller only
// has to say what the action is called and hand over an `ActionState`:
//
//   ActionButton { text: "LINK"; verbText: "LINKING"; action: link }
//   ActionState  { id: link }
//   onClicked: { link.begin(verbText); Wifi.connect(ssid) }
//
// A button with no `action` still flashes on press, which is all an instant
// action needs.
//
// **A button on a popup's bottom edge cuts its bottom-left corner** to sit
// parallel to the popup's own bottom-left chamfer -- set `cutBottomLeft` to the
// cut size. Every other corner stays square, so the button reads as square
// unless a host asks for the cut.
Item {
    id: root

    property real cutBottomLeft: 0

    property string text: ""
    // The verb shown while the action runs. Callers pass it to `begin` too, so
    // the button and any notification it raises agree on what was happening.
    property string verbText: ""
    property bool accented: false
    // Overrides the resting label colour, for a button that should read as
    // secondary -- DISMISS beside VIEW, say.
    property color textColor: accented ? Theme.accent : Theme.text
    property ActionState action: null
    // A button that is visible but cannot be used: greyed, unclickable, and
    // still hoverable so the host can explain why. `reason` is what it would
    // say; the host decides where to put it.
    property bool usable: true
    property string reason: ""

    signal hoveredChanged(bool hovered)

    readonly property bool working: action?.working ?? false
    readonly property bool failed: action?.failed ?? false
    readonly property bool succeeded: action?.succeeded ?? false

    signal clicked

    // Failure borrows the label rather than finding room for a second line;
    // it is only up for three seconds.
    readonly property string display: {
        if (failed)
            return action.reason ? `FAILED${Appearance.separator}${action.reason}` : "FAILED";
        if (working)
            return verbText || text;
        return text;
    }


    // The failure jolt, driven by the shared Feedback.
    transform: [
        Matrix4x4 {
            property real skew: feedback.shove * -4
            matrix: Qt.matrix4x4(1, Math.tan(skew * Math.PI / 180), 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1)
        },
        Translate {
            x: feedback.shove * 5
        }
    ]

    // **Every label this button can ever show**, so it can reserve the widest
    // of them. A host that knows of others -- a second resting label, a state
    // it swaps the text for -- adds them here.
    property var alsoText: []

    readonly property var labels: {
        const out = [root.text, "FAILED"];
        if (root.verbText)
            out.push(root.verbText);
        for (const extra of root.alsoText)
            out.push(extra);
        return out;
    }

    // A `Column`'s implicit width is the widest of its children, which is
    // exactly the question being asked. The labels are real `NrLabel`s rather
    // than `TextMetrics`, so the measurement is made by the same component
    // that does the drawing and cannot drift from it.
    Column {
        id: reserve

        visible: false

        Repeater {
            model: root.labels

            NrLabel {
                required property string modelData

                text: modelData
            }
        }
    }

    // The block is reserved whether or not it is running, so starting the work
    // does not widen the button. Only a button with an action can ever show
    // one; an instant action's button does not pay for a state it has not got.
    readonly property real workReserve: root.action ? segments.implicitWidth + 8 : 0

    // **The widest state, always.** This used to be `content.implicitWidth`,
    // which is the width of whatever the button happens to be saying: a verb
    // is longer than its resting label and the four-segment block is 29 px on
    // top of that, so every button grew the moment it was pressed. The
    // Bluetooth row is where it showed -- `UNLINKING` ran straight through its
    // neighbours -- but every action button in the shell did it.
    implicitWidth: reserve.implicitWidth + root.workReserve + 20
    implicitHeight: 24

    // The fill and frame, drawn as one chamfered shape so the bottom-left cut
    // is possible. Square on every corner but the one a host asks to cut.
    ChamferPanel {
        id: bg

        anchors.fill: parent
        scanlines: false

        chamfer: 0
        chamferTopLeft: 0
        chamferTopRight: 0
        chamferBottomRight: 0
        chamferBottomLeft: root.cutBottomLeft

        fillColor: {
            if (!root.usable)
                return "transparent";
            if (root.failed)
                return Theme.alpha(Theme.accent, 0.12);
            if (root.accented)
                return Theme.alpha(Theme.accent, 0.12);
            return hover.hovered ? Theme.alpha(Theme.hair, 0.35) : "transparent";
        }
        // The press flash brightens the border with it, which is what makes a
        // click on a transparent button read as a press at all.
        borderColor: {
            if (!root.usable)
                return Theme.alpha(Theme.hair, 0.5);
            if (root.failed || feedback.flashing)
                return Theme.accent;
            if (root.working)
                return Theme.alpha(Theme.accent, 0.6);
            return root.accented ? Theme.accent : Theme.hair;
        }

        Behavior on fillColor {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }

        Behavior on borderColor {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }
    }

    // **The row's width is the same in every state; the label's slot inside it
    // is not.** Reserving the block's space to the right of a fixed label slot
    // kept the button still but left every resting label 18 px left of its own
    // centre -- measured on the Wi-Fi row's `UNLINK`: ink centre 71 against a
    // box centre of 89. So the slot takes the block's space back while there
    // is no block in it, and gives it up when one appears. The two widths come
    // to the same number, which is the whole point:
    //
    //   idle    slot = label + block        = label + 8 + 29
    //   working slot = label, then 8, then 29
    //
    // Nothing outside the button moves in either case, and the label is
    // centred in the button whenever it is the only thing in it.
    Row {
        id: content

        anchors.centerIn: parent
        spacing: root.working ? 8 : 0

        NrLabel {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            // A fixed slot, aligned within it. A failure reason longer than
            // the slot elides rather than widening the button, and the
            // sentence it came from is in the notification.
            //
            // **A button the host has made wider gives the extra width to the
            // label.** The Bluetooth block's `UNLINK` spans the block, and the
            // slot stayed at its natural 110 px inside a 324 px button, so
            // `FAILED // OUT OF RANGE` elided to `FAILED // OU...` with 200 px
            // of empty button beside it. On a button at its own natural width
            // this is the same number it always was.
            width: Math.max(reserve.implicitWidth + (root.working ? 0 : root.workReserve), root.width - 20 - (root.working ? root.workReserve : 0))
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            centred: true
            text: root.display
            color: {
                if (!root.usable)
                    return Theme.mute;
                if (root.failed)
                    return Theme.accent;
                if (root.working)
                    return Theme.dim;
                return root.textColor;
            }
        }

        WorkSegments {
            id: segments

            anchors.verticalCenter: parent.verticalCenter
            visible: root.working
            running: root.working
        }
    }

    // Public so a button activated by something other than the pointer -- a
    // keyboard shortcut, a test -- still acknowledges it the same way.
    function flash(): void {
        feedback.flash();
    }

    Feedback {
        id: feedback

        anchors.fill: parent
        working: root.working
        succeeded: root.succeeded
        failed: root.failed
    }

    HoverHandler {
        id: hover

        // An unusable button still reports hover -- that is how its host knows
        // to explain itself -- but a working one does not.
        enabled: !root.working
        onHoveredChanged: root.hoveredChanged(hovered)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: root.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
        // Disabled while working so the action cannot be started twice, and
        // when the action is not available at all.
        enabled: !root.working && root.usable

        // The flash goes on press, not on click, so the acknowledgement is on
        // screen before the button even knows whether it was a click.
        onPressed: feedback.flash()
        // One frame between the flash and the work, so the flash is always
        // painted first however long the action then blocks for.
        onClicked: defer.restart()
    }

    Timer {
        id: defer

        interval: 16
        onTriggered: root.clicked()
    }
}
