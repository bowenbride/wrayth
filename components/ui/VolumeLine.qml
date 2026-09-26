import QtQuick
import qs.components as C
import qs.config

// VolumeLine (DESIGN.md): a SegmentMeter, the percentage at 10 px `text`
// right-aligned in a 34 px slot, then a 24 x 20 icon button that toggles
// mute (`volume_up`/`volume_off`, or `mic`/`mic_off`), `accent` while muted.
Item {
    id: root

    property real value: 0
    property bool muted: false
    property bool mic: false
    signal picked(real value)
    signal muteToggled

    implicitHeight: Tokens.measure.muteButtonHeight

    SegmentMeter {
        anchors.left: parent.left
        anchors.right: percent.left
        anchors.rightMargin: Tokens.space.s6
        anchors.verticalCenter: parent.verticalCenter
        value: root.value
        muted: root.muted
        settable: true
        onPicked: v => root.picked(v)
    }
    Text {
        id: percent
        readonly property var role: Tokens.type.percent
        anchors.right: button.left
        anchors.verticalCenter: parent.verticalCenter
        width: Tokens.measure.percentSlot
        horizontalAlignment: Text.AlignRight
        text: `${Math.round(root.value * 100)}%`
        color: Tokens.color.text
        font.family: role.family
        font.pixelSize: role.size
        font.features: ({ "tnum": 1 })
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
    }
    Item {
        id: button
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: Tokens.measure.muteButtonWidth
        height: Tokens.measure.muteButtonHeight

        C.Icon {
            anchors.centerIn: parent
            size: Tokens.icon.inline
            name: root.mic ? (root.muted ? "mic_off" : "mic") : (root.muted ? "volume_off" : "volume_up")
            color: root.muted ? Tokens.color.accent : (hover.hovered ? Tokens.color.text : Tokens.color.dim)
        }
        HoverHandler {
            id: hover
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: root.muteToggled()
        }
    }
}
