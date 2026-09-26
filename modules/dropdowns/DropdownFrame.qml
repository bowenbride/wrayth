import QtQuick
import qs.components
import qs.components.ui as UI
import qs.config

// The dropdown template (DESIGN.md): a 1 px ring with 12 px chamfers top-right
// and bottom-left, `panel2` fill, 14 px padding, one of the three standard
// widths. Header: Title + JapaneseLabel on the left, at most one header
// control on the right (a Toggle, or a quiet icon button). Body below a Rule.
ChamferPanel {
    id: root

    property string title: ""
    property string katakana: ""
    default property alias body: content.data
    property alias headerRight: right.data
    // Hides the header (a sub-view puts its BackControl and title on its own row).
    property bool showHeader: true

    readonly property real padding: Tokens.measure.dropdownPadding
    // Read by Dropdowns: small 340, standard 400 or wide 520 (DESIGN.md).
    property int panelWidth: Tokens.measure.dropdownStandard

    implicitWidth: panelWidth
    chamfer: Tokens.chamfer.dropdown
    fillColor: Tokens.color.panel2

    Item {
        id: header

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: root.padding
        height: root.showHeader ? Tokens.measure.toggleHeight : 0
        visible: root.showHeader

        UI.Title {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.title
            japanese: root.katakana
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

    UI.Rule {
        id: rule

        visible: root.showHeader
        anchors.top: header.bottom
        anchors.topMargin: root.showHeader ? Tokens.space.s10 : 0
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        width: undefined
    }

    Item {
        id: content

        anchors.top: root.showHeader ? rule.bottom : header.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: root.showHeader ? Tokens.measure.sectionGap : 0
        anchors.leftMargin: root.padding
        anchors.rightMargin: root.padding
        height: childrenRect.height
    }

    implicitHeight: content.y + content.height + root.padding
}
