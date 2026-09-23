import QtQuick
import qs.config

// A fixed-width, right-aligned text cell with tabular digits. Every changing
// number on the bar lives in one of these, so nothing shifts as values update.
Item {
    id: root

    property alias text: label.text
    property alias color: label.color
    property alias font: label.font
    property int horizontalAlignment: Text.AlignRight

    implicitWidth: 40
    implicitHeight: label.implicitHeight

    Text {
        id: label

        anchors.fill: parent

        horizontalAlignment: root.horizontalAlignment
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        maximumLineCount: 1

        color: Theme.text
        font.family: Appearance.font.data
        font.pixelSize: Appearance.size.body
        font.weight: Appearance.font.weightSemi
        font.features: Appearance.tabularFigures
        renderType: Text.NativeRendering
    }
}
