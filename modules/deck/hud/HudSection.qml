import QtQuick
import qs.components
import qs.config

// A labelled block in the HUD: a small header line, then whatever it measures.
Item {
    id: root

    property string label: ""
    property string katakana: ""
    // A value on the right of the heading line, as MEM's percentage.
    property string trailing: ""
    // The daemons' heading opens the library; every other heading is inert.
    property bool headingClickable: false
    default property alias body: content.data

    signal headingClicked

    implicitWidth: parent ? parent.width : 0
    implicitHeight: content.y + content.childrenRect.height

    Row {
        id: heading

        spacing: 8

        NrLabel {
            id: taggedTitle

            anchors.verticalCenter: parent.verticalCenter
            text: root.label
        }

        KanaTag {
            anchors.verticalCenter: parent.verticalCenter
            visible: root.katakana !== ""
            text: root.katakana
            title: taggedTitle
        }
    }

    // Beside the heading, not inside it: a Row lays out its children, so an
    // overlay declared in there is positioned as another column -- and Qt
    // refuses left/fill anchors there outright.
    Feedback {
        id: headingFeedback

        x: heading.x
        y: heading.y
        width: heading.width
        height: heading.height
        flashOpacity: 0.2
    }

    MouseArea {
        x: heading.x
        y: heading.y
        width: heading.width
        height: heading.height

        enabled: root.headingClickable
        cursorShape: Qt.PointingHandCursor
        onPressed: headingFeedback.flash()
        onClicked: root.headingClicked()
    }

    NrLabel {
        anchors.right: parent.right
        anchors.verticalCenter: heading.verticalCenter
        visible: root.trailing !== ""
        color: Theme.text
        text: root.trailing
    }

    Item {
        id: content

        anchors.top: heading.bottom
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.right: parent.right
        height: childrenRect.height
    }
}
