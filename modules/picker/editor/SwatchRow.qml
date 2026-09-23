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
        color: root.selected ? Theme.alpha(Theme.accent, 0.12) : hover.hovered ? Theme.alpha(Theme.hair, 0.3) : "transparent"
        border.width: Appearance.metrics.hairline
        border.color: root.selected ? Theme.accent : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
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
        border.width: Appearance.metrics.hairline
        border.color: Theme.hair
    }

    NrLabel {
        id: name

        anchors.left: swatch.right
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        width: 66
        color: root.selected ? Theme.accent : Theme.bright
        text: root.tokenKey
    }

    NrLabel {
        anchors.left: name.right
        anchors.leftMargin: 8
        anchors.right: hex.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        color: Theme.text
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
        color: Theme.text
        font.family: Appearance.font.data
        font.pixelSize: 11
        font.weight: Appearance.font.weightSemi
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
