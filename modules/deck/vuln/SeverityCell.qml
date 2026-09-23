import QtQuick
import qs.components
import qs.config

// One of the three severity tallies. HIGH wears the accent with a tinted fill,
// MED the alert colour, LOW nothing at all.
Rectangle {
    id: root

    property string label: ""
    property int count: 0
    property color tone: Theme.dim
    property bool filled: false

    implicitHeight: 26

    color: root.filled ? Theme.alpha(root.tone, 0.15) : "transparent"
    border.width: Appearance.metrics.hairline
    border.color: root.filled ? root.tone : Theme.hair

    Row {
        anchors.centerIn: parent
        spacing: 8

        NrLabel {
            anchors.verticalCenter: parent.verticalCenter
            color: root.tone
            text: root.label
        }

        // A fixed three-digit slot, so the label beside it holds still as the
        // figure changes. The pair is centred in the cell; the figure is
        // centred in its own slot.
        Text {
            id: value

            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(implicitWidth, countReserve.advanceWidth)
            horizontalAlignment: Text.AlignHCenter
            text: root.count
            color: root.tone
            font.family: Appearance.font.data
            font.pixelSize: Appearance.size.body
            font.weight: Appearance.font.weightSemi
            renderType: Text.NativeRendering
        }
    }

    TextMetrics {
        id: countReserve

        font: value.font
        text: "000"
    }
}
