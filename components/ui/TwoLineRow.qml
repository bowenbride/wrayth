import QtQuick
import qs.components as C
import qs.config

// TwoLineRow (DESIGN.md): at least 44 px; a 9 px meta line on top (app,
// count, time), the main text at 11 px below. Notifications.
Item {
    id: root

    property string meta: ""
    property string metaRight: ""
    property string text: ""
    property bool unread: false
    property bool selected: false
    // A count after the meta, `accent` while `unread`.
    property string count: ""
    // Room on the right for a trailing control (a chevron), and the control.
    property real trailing: 0
    default property alias extra: overlay.data
    signal clicked

    implicitHeight: Math.max(Tokens.measure.twoLineRow, lines.implicitHeight + 2 * Tokens.space.s8)

    Rectangle {
        anchors.fill: parent
        color: root.selected ? Tokens.color.rowSelected : (hover.hovered ? Tokens.color.rowHover : "transparent")
    }
    Rectangle {
        visible: root.unread || root.selected
        width: 2
        height: parent.height
        color: Tokens.color.accent
    }
    Column {
        id: lines

        x: Tokens.measure.rowPadding
        width: parent.width - 2 * Tokens.measure.rowPadding - root.trailing
        anchors.verticalCenter: parent.verticalCenter
        spacing: Tokens.space.s4

        Item {
            width: parent.width
            height: metaText.implicitHeight
            Text {
                id: countText
                readonly property var role: Tokens.type.rowMeta
                x: metaText.implicitWidth + Tokens.space.s6
                visible: root.count !== ""
                text: root.count
                color: root.unread ? Tokens.color.accent : Tokens.color.dim
                font.family: role.family
                font.pixelSize: role.size
                font.letterSpacing: role.size * role.tracking
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
            }
            Text {
                id: metaText
                readonly property var role: Tokens.type.rowMeta
                text: root.meta
                color: Tokens.color.dim
                font.family: role.family
                font.pixelSize: role.size
                font.letterSpacing: role.size * role.tracking
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
            }
            Text {
                readonly property var role: Tokens.type.rowMeta
                anchors.right: parent.right
                text: root.metaRight
                color: Tokens.color.dim
                font.family: role.family
                font.pixelSize: role.size
                font.letterSpacing: role.size * role.tracking
                textFormat: Text.PlainText
                renderType: Text.NativeRendering
            }
        }
        Text {
            readonly property var role: Tokens.type.body
            width: parent.width
            elide: Text.ElideRight
            text: root.text
            color: root.unread ? Tokens.color.bright : Tokens.color.text
            font.family: role.family
            font.pixelSize: role.size
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
        }
    }
    Item {
        id: overlay
        anchors.fill: parent
        z: 1
    }
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    // A tap on the trailing control is the control's, not the row's.
    // The shared press flash (DESIGN.md: interaction states), on press, so
    // the acknowledgement paints before the action.
    C.Feedback {
        id: pressFlash
        anchors.fill: parent
    }
    TapHandler {
        onPressedChanged: if (pressed) pressFlash.flash()
        onTapped: (point) => {
            if (point.position.x < root.width - root.trailing)
                root.clicked();
        }
    }
}
