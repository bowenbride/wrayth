import QtQuick
import qs.components as C
import qs.config

// Button (DESIGN.md), three kinds:
//   primary    the one main action of a view; rare. 1 px `accent` frame, 12%
//              `accent` tint, label `accent`.
//   secondary  1 px `hair` frame, `panelHex` fill, label `text`.
//   quiet      no frame, no fill, label `dim` (hover `text`), optional 14 px
//              chevron.
// Framed buttons are 28 px full-width, 22 px inline; a chamfer only by the
// corner-echo rule (`cutBottomLeft`, `cutTopLeft`).
Item {
    id: root

    property string kind: "secondary"
    property string text: ""
    property bool enabled: true
    property bool inline: false
    property string chevron: ""        // "", "left" or "right" (quiet buttons)
    property int cutBottomLeft: 0
    property int cutTopLeft: 0
    // Every label the button can show, so it reserves the widest (overlap rule).
    property var alsoText: []
    signal clicked

    readonly property bool quiet: kind === "quiet"
    readonly property var role: Tokens.type.button

    implicitWidth: (quiet ? 0 : 2 * Tokens.space.s12) + reserve.width + (chevron !== "" ? Tokens.icon.chevron + Tokens.space.s2 : 0)
    implicitHeight: quiet ? Tokens.measure.buttonInline : (inline ? Tokens.measure.buttonInline : Tokens.measure.buttonFull)
    opacity: enabled ? 1 : 0.4

    TextMetrics {
        id: reserve
        font: label.font
        text: [root.text].concat(root.alsoText).reduce((a, b) => b.length > a.length ? b : a, "")
    }

    C.ChamferPanel {
        anchors.fill: parent
        visible: !root.quiet
        scanlines: false
        chamfer: 0
        chamferTopLeft: root.cutTopLeft
        chamferTopRight: 0
        chamferBottomRight: 0
        chamferBottomLeft: root.cutBottomLeft
        fillColor: root.kind === "primary" ? Tokens.color.accentTint : Tokens.color.panelHex
        borderColor: root.kind === "primary" ? Tokens.color.accent : Tokens.color.hair
    }

    Row {
        anchors.centerIn: parent
        spacing: Tokens.space.s2
        layoutDirection: root.chevron === "left" ? Qt.LeftToRight : Qt.RightToLeft

        C.Icon {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.chevron !== ""
            name: root.chevron === "left" ? "chevron_left" : "chevron_right"
            size: Tokens.icon.chevron
            color: label.color
        }
        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            text: root.text
            color: root.kind === "primary" ? Tokens.color.accent : (root.quiet ? (hover.hovered && root.enabled ? Tokens.color.text : Tokens.color.dim) : Tokens.color.text)
            font.family: root.role.family
            font.pixelSize: root.role.size
            font.weight: root.role.weight
            font.letterSpacing: root.role.size * root.role.tracking
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
            Behavior on color {
                ColorAnimation {
                    duration: Tokens.motion.feedback
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.motion.easeIn
                }
            }
        }
    }
    HoverHandler {
        id: hover
        cursorShape: root.enabled ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
    // The shared press flash (DESIGN.md: interaction states), on press, so
    // the acknowledgement paints before the action.
    C.Feedback {
        id: pressFlash
        anchors.fill: parent
    }
    TapHandler {
        onPressedChanged: if (pressed) pressFlash.flash()
        enabled: root.enabled
        onTapped: root.clicked()
    }
}
