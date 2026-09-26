import QtQuick
import qs.config

// IndicatorChip (DESIGN.md): a privacy indicator -- a Chip with a 6 x 6 dot.
// REC: `accent`, the dot pulsing (opacity 1 to 0.35, 1.2 s). SHARE, MIC, CAM:
// `alert`. Only running while visible.
Rectangle {
    id: root

    property alias text: label.text
    property bool rec: false
    readonly property color tone: rec ? Tokens.color.accent : Tokens.color.alert
    signal clicked

    implicitWidth: row.implicitWidth + 2 * Tokens.measure.chipPadding
    implicitHeight: Tokens.measure.chip
    color: Qt.alpha(tone, 0.12)
    border.width: Tokens.measure.hairline
    border.color: tone

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Tokens.space.s6

        StatusDot {
            id: dot
            anchors.verticalCenter: parent.verticalCenter
            onIcon: true
            color: root.tone
            SequentialAnimation on opacity {
                running: root.rec && root.visible
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.35
                    duration: 600
                    easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    to: 1
                    duration: 600
                    easing.type: Easing.InOutSine
                }
            }
        }
        Text {
            id: label
            readonly property var role: Tokens.type.chip
            anchors.verticalCenter: parent.verticalCenter
            color: root.tone
            font.family: role.family
            font.pixelSize: role.size
            font.weight: role.weight
            font.letterSpacing: role.size * role.tracking
            font.features: ({ "tnum": 1 })
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
        }
    }
    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: root.clicked()
    }
}
