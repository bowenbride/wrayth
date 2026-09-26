import QtQuick
import qs.components
import qs.config

// One of the nine colours: its swatch, its name, what it is for, and its hex.
Item {
    id: root

    required property string tokenKey
    required property string role
    required property string value
    required property bool selected

    signal picked

    implicitHeight: 38

    Rectangle {
        anchors.fill: parent
        color: root.selected ? Tokens.color.accentTint : hover.hovered ? Theme.alpha(Tokens.color.hair, 0.3) : "transparent"
        border.width: Tokens.measure.hairline
        border.color: root.selected ? Tokens.color.accent : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Tokens.motion.feedback
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Tokens.motion.easeIn
            }
        }
    }

    Rectangle {
        id: swatch

        anchors.left: parent.left
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 30
        height: 22
        color: root.value
        border.width: Tokens.measure.hairline
        border.color: Tokens.color.hair
    }

    NrLabel {
        id: name

        anchors.left: swatch.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 66
        color: root.selected ? Tokens.color.accent : Tokens.color.bright
        text: root.tokenKey
    }

    NrLabel {
        anchors.left: name.right
        anchors.leftMargin: 8
        anchors.right: hex.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        color: Tokens.color.text
        pixelSize: 10
        elide: Text.ElideRight
        text: root.role
    }

    Text {
        id: hex

        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter

        text: root.value.toUpperCase()
        color: Tokens.color.text
        font.family: Tokens.font.data
        font.pixelSize: 11
        font.weight: Tokens.font.dataWeight
        renderType: Text.NativeRendering
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.picked()
    }
}
