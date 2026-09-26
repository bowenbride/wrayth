import QtQuick
import qs.components as C
import qs.config

// Chip (DESIGN.md): 22 px, 8 px sides, 1 px `hair` border, label 9 px `dim`.
// Selected: `accent` border, 12% `accent` tint, `accent` label. An optional
// 5 x 5 status dot before the label.
Rectangle {
    id: root

    property alias text: label.text
    property bool selected: false
    property bool dot: false
    property color dotColor: Tokens.color.accent
    property color tone: Tokens.color.accent
    signal clicked

    implicitWidth: row.implicitWidth + 2 * Tokens.measure.chipPadding
    implicitHeight: Tokens.measure.chip
    color: selected ? Qt.alpha(tone, 0.12) : "transparent"
    border.width: Tokens.measure.hairline
    border.color: selected ? tone : Tokens.color.hair

    Behavior on color {
        ColorAnimation {
            duration: Tokens.motion.feedback
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.motion.easeIn
        }
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.space.s6

        StatusDot {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.dot
            color: root.dotColor
        }
        Text {
            id: label
            readonly property var role: Tokens.type.chip
            anchors.verticalCenter: parent.verticalCenter
            color: root.selected ? root.tone : Tokens.color.dim
            font.family: role.family
            font.pixelSize: role.size
            font.weight: role.weight
            font.letterSpacing: role.size * role.tracking
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
        }
    }
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
    // The shared press flash (DESIGN.md: interaction states), on press, so
    // the acknowledgement paints before the action.
    C.Feedback {
        id: pressFlash
        anchors.fill: parent
    }
    TapHandler {
        onPressedChanged: if (pressed) pressFlash.flash()
        onTapped: root.clicked()
    }
}
