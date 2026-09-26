import QtQuick
import qs.config

// BarDivider (DESIGN.md): a 1 x 16 px `hair` line, vertically centred, with
// 12 px either side. Between every two bar items.
Item {
    implicitWidth: Tokens.measure.barGap * 2 + Tokens.measure.hairline
    implicitHeight: Tokens.measure.barDividerHeight

    Rectangle {
        x: Tokens.measure.barGap
        anchors.verticalCenter: parent.verticalCenter
        width: Tokens.measure.hairline
        height: Tokens.measure.barDividerHeight
        color: Tokens.color.hair
    }
}
