import QtQuick
import qs.config

// SectionLabel (DESIGN.md): names a group inside a surface. 9 px, 0.18em,
// `dim`, with 12 px above it.
Text {
    readonly property var role: Tokens.type.sectionLabel

    topPadding: Tokens.measure.sectionGap
    color: Tokens.color.dim
    font.family: role.family
    font.pixelSize: role.size
    font.weight: role.weight
    font.letterSpacing: role.size * role.tracking
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
}
