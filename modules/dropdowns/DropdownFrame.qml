import QtQuick
import qs.components
import qs.config

// The shell every bar dropdown shares: chamfered panel2 with blur, a header of
// title + katakana + a right-hand slot, and a hairline under it.
ChamferPanel {
    id: root

    property string title: ""
    property string katakana: ""
    // The title's size and tracking (em); the defaults are every dropdown's.
    property real titleSize: Appearance.size.label
    property real titleTracking: -1
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
                id: taggedTitle

                anchors.verticalCenter: parent.verticalCenter
                pixelSize: root.titleSize
                font.letterSpacing: root.titleTracking >= 0 ? root.titleSize * root.titleTracking : Appearance.tracking(root.titleSize)
                color: Theme.bright
                text: root.title
            }

            KanaTag {
                anchors.verticalCenter: parent.verticalCenter
                text: root.katakana
                title: taggedTitle
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
