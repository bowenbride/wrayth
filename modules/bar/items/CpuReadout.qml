import QtQuick
import qs.components
import qs.config
import qs.services
import qs.utils

Row {
    spacing: 7

    NrLabel {
        anchors.verticalCenter: parent.verticalCenter
        text: "CPU"
    }

    SegmentMeter {
        anchors.verticalCenter: parent.verticalCenter
        segments: Appearance.metrics.meterSegments
        segmentWidth: Appearance.metrics.meterSegmentWidth
        segmentHeight: Appearance.metrics.meterSegmentHeight
        value: SysInfo.cpuPercent / 100
        litColor: Theme.signal
    }

    Slot {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Appearance.slot.percent
        text: Fmt.percent(SysInfo.cpuPercent)
    }
}
