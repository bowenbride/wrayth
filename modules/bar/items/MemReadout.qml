import QtQuick
import qs.components as C
import qs.components.ui
import qs.config
import qs.services
import qs.utils

// MEM (DESIGN.md): Label, then Value (used/total), in a slot as wide as the
// widest it can read: the total over itself.
Row {
    spacing: Tokens.space.s8

    Label {
        anchors.verticalCenter: parent.verticalCenter
        bar: true
        text: "MEM"
    }
    // The small meter, as built before the style pass (DESIGN.md).
    C.SegmentMeter {
        anchors.verticalCenter: parent.verticalCenter
        segments: Tokens.measure.barMeterSegments
        segmentWidth: Tokens.measure.barMeterSegmentWidth
        segmentHeight: Tokens.measure.barMeterSegmentHeight
        value: SysInfo.memPercent / 100
        litColor: Tokens.color.signal
    }

    Value {
        anchors.verticalCenter: parent.verticalCenter
        bar: true
        width: widest.width
        horizontalAlignment: Text.AlignRight
        text: `${Fmt.gib(SysInfo.memUsedGib, 1)}/${Fmt.gib(SysInfo.memTotalGib, 1)}G`

        TextMetrics {
            id: widest
            font: parent.font
            text: `${Fmt.gib(SysInfo.memTotalGib, 1)}/${Fmt.gib(SysInfo.memTotalGib, 1)}G`
        }
    }
}
