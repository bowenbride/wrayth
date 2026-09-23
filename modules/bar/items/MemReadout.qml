import QtQuick
import qs.components
import qs.config
import qs.services
import qs.utils

Row {
    spacing: 7

    NrLabel {
        anchors.verticalCenter: parent.verticalCenter
        text: "MEM"
    }

    SegmentMeter {
        anchors.verticalCenter: parent.verticalCenter
        segments: Appearance.metrics.meterSegments
        segmentWidth: Appearance.metrics.meterSegmentWidth
        segmentHeight: Appearance.metrics.meterSegmentHeight
        value: SysInfo.memPercent / 100
        litColor: Theme.signal
    }

    Slot {
        anchors.verticalCenter: parent.verticalCenter
        implicitWidth: Appearance.slot.memory
        text: `${Fmt.gib(SysInfo.memUsedGib, 1)}/${Fmt.gib(SysInfo.memTotalGib, 1)}G`
    }
}
