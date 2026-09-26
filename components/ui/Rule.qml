import QtQuick
import qs.config

// Rule (DESIGN.md): a full-width 1 px `hair` line.
Rectangle {
    width: parent ? parent.width : 0
    implicitHeight: Tokens.measure.hairline
    height: Tokens.measure.hairline
    color: Tokens.color.hair
}
