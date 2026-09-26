import QtQuick
import qs.config

// StatusDot (DESIGN.md): a square, never a circle. 5 x 5 in chips and rows,
// 6 x 6 on icons.
Rectangle {
    property bool onIcon: false

    width: onIcon ? Tokens.measure.iconDot : Tokens.measure.statusDot
    height: width
    color: Tokens.color.accent
}
