import QtQuick
import qs.components
import qs.config

// A label and its value side by side, as the HUD writes LOAD / TEMP / FREQ and
// the daemon lines.
Row {
    id: root

    property string label: ""
    property string value: ""
    property color valueColor: Theme.signal
    property bool glow: false
    // Daemon names are programs, not labels: the spec writes them as
    // `SHIELD nftables`, so their case is left alone.
    property bool upperLabel: true

    // **The widest string this value can ever be.** A readout whose value is
    // centred or trailed by something else moves that something every time the
    // figure changes width -- `9°C` to `100°C` is 18 px. Set this and the
    // value sits in a fixed slot instead. Left empty the slot is the value's
    // own width, which is right for a readout anchored by its left edge with
    // nothing after it.
    property string valueReserve: ""

    spacing: 6

    NrLabel {
        anchors.verticalCenter: parent.verticalCenter
        text: root.label
        font.capitalization: root.upperLabel ? Font.AllUppercase : Font.MixedCase
    }

    Text {
        id: valueText

        renderType: Text.NativeRendering
        anchors.verticalCenter: parent.verticalCenter

        width: root.valueReserve ? reserve.advanceWidth : implicitWidth
        text: root.value
        color: root.valueColor
        font.family: Appearance.font.data
        font.pixelSize: Appearance.size.body
        font.weight: Appearance.font.weightSemi
    }

    TextMetrics {
        id: reserve

        font: valueText.font
        text: root.valueReserve
    }
}
