import QtQuick
import qs.config

// EmptyState (DESIGN.md): centred 10 px, 0.14em, `dim`, in the space the
// content would fill: ALL CLEAR, NO SIGNAL, NO VPNS SET UP.
Item {
    property alias text: label.text

    implicitHeight: label.implicitHeight + 2 * Tokens.space.s20

    Text {
        id: label

        readonly property var role: Tokens.type.emptyState
        anchors.centerIn: parent
        color: Tokens.color.dim
        font.family: role.family
        font.pixelSize: role.size
        font.weight: role.weight
        font.letterSpacing: role.size * role.tracking
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
    }
}
