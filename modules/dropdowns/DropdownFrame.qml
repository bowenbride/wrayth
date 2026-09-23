import QtQuick
import qs.components
import qs.config

// The shell every bar dropdown shares: chamfered panel2 with blur, a header of
// title + katakana + a right-hand slot, and a hairline under it.
ChamferPanel {
    id: root

    property string title: ""
    property string katakana: ""
    default property alias body: content.data
    property alias headerRight: right.data

    readonly property real padding: 14

    implicitWidth: 380
    chamfer: Appearance.chamfer.panel
    fillColor: Theme.panel2

    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.padding
        height: 22

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            NrLabel {
                anchors.verticalCenter: parent.verticalCenter
                pixelSize: Appearance.size.label
                color: Theme.bright
                text: root.title
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: root.katakana
                color: Theme.signal
                font.family: Appearance.font.accent
                font.pixelSize: Appearance.size.katakana
                font.weight: Appearance.font.weightMedium
                renderType: Text.NativeRendering
            }
        }

        Item {
            id: right

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            implicitWidth: childrenRect.width
            implicitHeight: childrenRect.height
            width: implicitWidth
            height: implicitHeight
        }
    }

    Rectangle {
        id: rule

        anchors.top: header.bottom
        anchors.topMargin: root.padding * 0.7
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        height: Appearance.metrics.hairline
        color: Theme.hair
    }

    Item {
        id: content

        anchors.top: rule.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.padding * 0.8
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        height: childrenRect.height
    }

    implicitHeight: content.y + content.height + root.padding
}
