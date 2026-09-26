import QtQuick
import qs.components
import qs.components.ui as UI
import qs.config
import qs.services

// INPUT (DESIGN.md): every keyboard layout and input method as a Row, its
// glyph in a slot at the left (accent when active), ACTIVE as the status in
// `signal`; a hint line naming the key.
DropdownFrame {
    id: root

    title: "INPUT"
    katakana: "入力"
    panelWidth: Tokens.measure.dropdownSmall

    Column {
        width: parent.width
        spacing: 0

        UI.EmptyState {
            width: parent.width
            visible: InputModes.modes.length === 0
            text: "ONE LAYOUT"
        }

        Repeater {
            model: InputModes.modes

            UI.ListRow {
                id: row

                required property var modelData
                required property int index
                readonly property bool active: index === InputModes.current

                width: parent.width
                name: modelData.name
                selected: active
                status: active ? "ACTIVE" : ""
                statusColor: Tokens.color.signal
                leading: Tokens.measure.badgeSmall + Tokens.space.s10
                onClicked: InputModes.select(index)

                // The mode's glyph (EN, あ, ア), a Value in a 22 px slot.
                Rectangle {
                    x: Tokens.measure.rowPadding
                    anchors.verticalCenter: parent.verticalCenter
                    width: Tokens.measure.badgeSmall
                    height: Tokens.measure.badgeSmall
                    color: "transparent"
                    border.width: Tokens.measure.hairline
                    border.color: row.active ? Tokens.color.accent : Tokens.color.hair

                    UI.Value {
                        anchors.centerIn: parent
                        text: row.modelData.glyph
                        color: row.active ? Tokens.color.accent : Tokens.color.text
                        font.pixelSize: Tokens.type.rowMeta.size
                    }
                }
            }
        }

        UI.Rule {}

        Text {
            readonly property var role: Tokens.type.hint
            topPadding: Tokens.space.s8
            text: "SWITCH WITH SUPER + SPACE"
            color: Tokens.color.dim
            font.family: role.family
            font.pixelSize: role.size
            font.letterSpacing: role.size * role.tracking
            renderType: Text.NativeRendering
        }
    }
}
