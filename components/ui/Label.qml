import QtQuick
import qs.config

// Label (DESIGN.md): a name for something. Always `dim`. The bar size on the
// bar, the hint size elsewhere. Uppercase is typed in the text itself.
Text {
    property bool bar: false
    readonly property var role: bar ? Tokens.type.barLabel : Tokens.type.hint

    color: Tokens.color.dim
    font.family: role.family
    font.pixelSize: role.size
    font.weight: role.weight
    font.letterSpacing: role.size * role.tracking
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
}
