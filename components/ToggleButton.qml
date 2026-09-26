import QtQuick
import qs.config

// The small ON/OFF switch used across the dropdowns.
//
// Hand it an `ActionState` when the thing it switches takes time to come up --
// a radio, discovery -- and it shows the verb and the sweep like any other
// action. Left without one it is an instant toggle and only flashes.
Rectangle {
    id: root

    property bool on: false
    property string onText: "ON"
    property string offText: "OFF"
    property ActionState action: null
    // A switch that is visible but cannot be used: greyed and unclickable,
    // the same contract `ActionButton.usable` carries. It exists because a
    // control that answers a press by doing nothing at all is worse than one
    // that says it is unavailable -- the Bluetooth radio with no adapter
    // behind it was exactly that.
    property bool usable: true

    readonly property bool working: action?.working ?? false
    readonly property bool failed: action?.failed ?? false

    signal toggled


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

    // **Every label this switch can ever show**, so it reserves the widest of
    // them and none of its states changes its size. A caller that knows of
    // another adds it here.
    property var alsoText: []

    readonly property var labels: {
        const out = [root.onText, root.offText, "FAILED"];
        if (root.action?.verb)
            out.push(root.action.verb);
        for (const extra of root.alsoText)
            out.push(extra);
        return out;
    }

    // A `Column`'s implicit width is the widest of its children, measured by
    // the same component that draws them. See `ActionButton`, which does this
    // the same way and for the same reason.
    Column {
        id: reserve

        visible: false

        Repeater {
            model: root.labels

            NrLabel {
                required property string modelData

                pixelSize: Tokens.type.button.size
                font.letterSpacing: Tokens.type.button.size * Tokens.type.button.tracking
                text: modelData
            }
        }
    }

    // **Sized for its widest state, not for what it happens to say.** It used
    // to size to the live label and ease the change, so `ON` -> `ENABLING` ->
    // `FAILED // OUT OF RANGE` moved everything to its right, three times, in
    // one action.
    // DESIGN.md Toggle: 58 x 22, wider only for a longer state name.
    implicitWidth: Math.max(Tokens.measure.toggleWidth, reserve.implicitWidth + 2 * Tokens.space.s8)
    implicitHeight: Tokens.measure.toggleHeight

    color: !root.usable ? "transparent" : root.failed ? Tokens.color.accentTint : (on ? Tokens.color.accentTint : "transparent")
    border.width: Tokens.measure.hairline
    border.color: {
        if (!root.usable)
            return Theme.alpha(Tokens.color.hair, 0.5);
        if (root.failed || feedback.flashing)
            return Tokens.color.accent;
        if (root.working)
            return Theme.alpha(Tokens.color.accent, 0.6);
        return on ? Tokens.color.accent : Tokens.color.hair;
    }

    Behavior on color {
        ColorAnimation {
            duration: Tokens.motion.feedback
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.motion.easeIn
        }
    }
    Behavior on border.color {
        ColorAnimation {
            duration: Tokens.motion.feedback
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.motion.easeIn
        }
    }

    NrLabel {
        id: label

        anchors.fill: parent
        centred: true
        pixelSize: Tokens.type.button.size
        font.letterSpacing: Tokens.type.button.size * Tokens.type.button.tracking
        horizontalAlignment: Text.AlignHCenter
        // A reason longer than the slot elides inside it rather than widening
        // the switch; the sentence goes out as a notification.
        elide: Text.ElideRight
        text: {
            if (root.failed)
                return root.action.reason || "FAILED";
            if (root.working)
                return root.action.verb;
            return root.on ? root.onText : root.offText;
        }
        color: {
            if (!root.usable)
                return Tokens.color.mute;
            if (root.failed)
                return Tokens.color.accent;
            if (root.working)
                return Tokens.color.dim;
            return root.on ? Tokens.color.accent : Tokens.color.dim;
        }

        Behavior on color {
            ColorAnimation {
                duration: Tokens.motion.feedback
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeIn
            }
        }
    }

    Feedback {
        id: feedback

        anchors.fill: parent
        working: root.working
        succeeded: root.action?.succeeded ?? false
        failed: root.failed
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: root.usable ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: !root.working && root.usable

        onPressed: feedback.flash()
        onClicked: defer.restart()
    }

    Timer {
        id: defer

        interval: 16
        onTriggered: root.toggled()
    }
}
