import QtQuick
import qs.components as C
import qs.components.ui
import qs.config
import qs.services
import qs.utils

// CPU (DESIGN.md): Label, then Value, the value's slot as wide as its
// widest possible value (100%).
Row {
    spacing: Tokens.space.s8

    Label {
        anchors.verticalCenter: parent.verticalCenter
        bar: true
        text: "CPU"
    }
    // The small meter, as built before the style pass (DESIGN.md).
    C.SegmentMeter {
        anchors.verticalCenter: parent.verticalCenter
        segments: Tokens.measure.barMeterSegments
        segmentWidth: Tokens.measure.barMeterSegmentWidth
        segmentHeight: Tokens.measure.barMeterSegmentHeight
        value: SysInfo.cpuPercent / 100
        litColor: Tokens.color.signal
    }

    Value {
        anchors.verticalCenter: parent.verticalCenter
        bar: true
        width: widest.width
        horizontalAlignment: Text.AlignRight
        text: Fmt.percent(SysInfo.cpuPercent)

        TextMetrics {
            id: widest
            font: parent.font
            text: "100%"
        }
    }
}
