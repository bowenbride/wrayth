import QtQuick
import qs.config

// Title (DESIGN.md): a surface's title in the dropdown-title role, then its
// JapaneseLabel 8 px later.
Item {
    id: root

    property string text: ""
    property string japanese: ""

    implicitWidth: label.implicitWidth + (japanese !== "" ? Tokens.measure.japaneseGap + kana.implicitWidth : 0)
    implicitHeight: label.implicitHeight

    Text {
        id: label

        readonly property var role: Tokens.type.dropdownTitle
        text: root.text
        color: Tokens.color.text
        font.family: role.family
        font.pixelSize: role.size
        font.weight: role.weight
        font.letterSpacing: role.size * role.tracking
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
    }
    JapaneseLabel {
        id: kana

        x: label.implicitWidth + Tokens.measure.japaneseGap
        visible: root.japanese !== ""
        text: root.japanese
        title: label
    }
}
