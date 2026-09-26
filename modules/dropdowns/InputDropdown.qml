import QtQuick
import qs.components
import qs.config
import qs.services

// INPUT: every keyboard layout and input method, the active one marked.
DropdownFrame {
    id: root

    title: "INPUT"
    katakana: "入力"
    // Read by Dropdowns: this dropdown is 320 px wide.
    readonly property int panelWidth: 320

    Column {
        width: parent.width
        spacing: 0

        Repeater {
            model: InputModes.modes

            Item {
                id: row

                required property var modelData
                required property int index
                readonly property bool active: index === InputModes.current

                width: parent.width
                height: 32

                Rectangle {
                    anchors.fill: parent
                    color: row.active ? Theme.alpha(Theme.ground, 0.55) : (hover.hovered ? Theme.cell : "transparent")
                    Behavior on color {
                        ColorAnimation {
                            duration: Appearance.duration.state
                            easing.type: Easing.OutCubic
                        }
                    }
                }
                Feedback {
                    id: feedback
                    anchors.fill: parent
                }

                // The 22 px glyph slot: the accent when active.
                Rectangle {
                    id: slot

                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22
                    height: 22
                    color: row.active ? Theme.alpha(Theme.accent, 0.12) : "transparent"
                    border.width: 1
                    border.color: row.active ? Theme.accent : Theme.hair

                    Text {
                        anchors.centerIn: parent
                        text: row.modelData.glyph
                        color: row.active ? Theme.accent : Theme.text
                        font.family: Appearance.font.data
                        font.pixelSize: row.modelData.glyph.length > 2 ? 8 : 10
                        font.weight: Appearance.font.weightSemi
                        renderType: Text.NativeRendering
                    }
                }

                Text {
                    anchors.left: slot.right
                    anchors.leftMargin: 10
                    anchors.right: activeTag.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: row.modelData.name
                    textFormat: Text.PlainText
                    color: row.active ? Theme.bright : Theme.text
                    font.family: Appearance.font.data
                    font.pixelSize: 12
                    renderType: Text.NativeRendering
                }

                Text {
                    id: activeTag

                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: "ACTIVE"
                    opacity: row.active ? 1 : 0
                    color: Theme.signal
                    font.family: Appearance.font.data
                    font.pixelSize: 9
                    font.weight: Appearance.font.weightSemi
                    font.letterSpacing: 9 * 0.12
                    renderType: Text.NativeRendering
                }

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }
                TapHandler {
                    onPressedChanged: if (pressed) feedback.flash()
                    onTapped: InputModes.select(row.index)
                }
            }
        }

        Rectangle {
            width: parent.width
            height: Appearance.metrics.hairline
            color: Theme.hair
        }
        Item {
            width: parent.width
            height: 22

            Text {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                text: "SWITCH WITH SUPER + SPACE"
                color: Theme.dim
                font.family: Appearance.font.data
                font.pixelSize: 9
                font.letterSpacing: 9 * 0.12
                renderType: Text.NativeRendering
            }
        }
    }
}
