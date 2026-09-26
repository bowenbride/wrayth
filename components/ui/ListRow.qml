import QtQuick
import qs.components as C
import qs.config

// Row (DESIGN.md), named ListRow so it never shadows QtQuick's Row: 32 px,
// 10 px sides, the name at 12 px, optional meta at 10 px `dim` after it,
// optional status at 9 px on the right. Selected or active: a 2 px `accent`
// left edge, rgba(0,0,0,0.25) fill, name `bright`. Hover: rgba(0,0,0,0.15).
Item {
    id: root

    property string name: ""
    property string meta: ""
    property string status: ""
    property color statusColor: Tokens.color.dim
    property bool selected: false
    property bool enabled: true
    // Room on the left for a badge (BadgeRow sets it).
    property real leading: 0
    // Room on the right for a trailing control (a chevron).
    property real trailing: 0
    default property alias extra: content.data
    signal clicked
    signal rightClicked

    implicitHeight: Tokens.measure.row

    Rectangle {
        anchors.fill: parent
        color: root.selected ? Tokens.color.rowSelected : (hover.hovered && root.enabled ? Tokens.color.rowHover : "transparent")
        Behavior on color {
            ColorAnimation {
                duration: Tokens.motion.feedback
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeIn
            }
        }
    }
    Rectangle {
        visible: root.selected
        width: 2
        height: parent.height
        color: Tokens.color.accent
    }
    Item {
        id: content
        anchors.fill: parent
    }
    Row {
        anchors.left: parent.left
        anchors.leftMargin: Tokens.measure.rowPadding + root.leading
        anchors.right: statusText.left
        anchors.rightMargin: Tokens.space.s8
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.space.s8
        clip: true

        Text {
            readonly property var role: Tokens.type.rowName
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, parent.width - (metaText.visible ? metaText.implicitWidth + parent.spacing : 0))
            elide: Text.ElideRight
            text: root.name
            color: !root.enabled ? Tokens.color.mute : (root.selected ? Tokens.color.bright : Tokens.color.text)
            font.family: role.family
            font.pixelSize: role.size
            font.weight: role.weight
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
        }
        Text {
            id: metaText
            readonly property var role: Tokens.type.rowAfter
            anchors.verticalCenter: parent.verticalCenter
            visible: root.meta !== ""
            text: root.meta
            color: Tokens.color.dim
            font.family: role.family
            font.pixelSize: role.size
            font.weight: role.weight
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
        }
    }
    Text {
        id: statusText
        readonly property var role: Tokens.type.rowMeta
        anchors.right: parent.right
        anchors.rightMargin: Tokens.measure.rowPadding + root.trailing
        anchors.verticalCenter: parent.verticalCenter
        text: root.status
        color: root.statusColor
        font.family: role.family
        font.pixelSize: role.size
        font.weight: role.weight
        font.letterSpacing: role.size * role.tracking
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
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
    TapHandler {
        enabled: root.enabled
        acceptedButtons: Qt.RightButton
        onTapped: root.rightClicked()
    }
}
