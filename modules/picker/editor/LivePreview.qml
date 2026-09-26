import QtQuick
import qs.components
import qs.config
import qs.modules.picker.mini

// What the palette being edited would look like: the bar, a few terminal rows
// with a selection in them, and the SYS.DIAG panel. The same two miniatures
// the picker's cards use, with the terminal added -- the terminal is where
// most of a palette's work is seen, and `bright` on `ground` is the one pair
// no swatch can show you.
Item {
    id: root

    required property var palette

    implicitHeight: 300

    Rectangle {
        anchors.fill: parent
        color: root.palette.ground
        border.width: Appearance.metrics.hairline
        border.color: root.palette.hair
    }

    MiniBar {
        id: bar

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 1
        height: 20
        palette: root.palette
    }

    MiniDiag {
        id: diag

        anchors.top: bar.bottom
        anchors.right: parent.right
        anchors.topMargin: 18
        anchors.rightMargin: 14
        palette: root.palette
    }

    // A terminal, in the colours `wrayth-profile` writes into kitty's
    // config: the prompt in accent, body in text, katakana in signal, warnings
    // in alert, and the selection reversed -- `ground` on `bright`, which is
    // the locked rule and the same contrast in every palette.
    Column {
        anchors.top: bar.bottom
        anchors.left: parent.left
        anchors.topMargin: 18
        anchors.leftMargin: 14
        anchors.right: diag.left
        anchors.rightMargin: 16
        spacing: 7

        Row {
            spacing: 6

            Text {
                text: "wrayth"
                color: root.palette.accent
                font.family: Appearance.font.data
                font.pixelSize: 11
                font.weight: Appearance.font.weightSemi
                renderType: Text.NativeRendering
            }

            Text {
                text: "~/deck"
                color: root.palette.signal
                font.family: Appearance.font.data
                font.pixelSize: 11
                renderType: Text.NativeRendering
            }

            Text {
                text: "$"
                color: root.palette.dim
                font.family: Appearance.font.data
                font.pixelSize: 11
                renderType: Text.NativeRendering
            }
        }

        Text {
            text: "ICE NOMINAL // 25 SERVICES // UPLINK 12MS"
            color: root.palette.text
            font.family: Appearance.font.data
            font.pixelSize: 11
            renderType: Text.NativeRendering
        }

        // The selection sample. It is a filled box rather than a real
        // selection because there is nothing here to select; the colours are
        // the ones kitty is given.
        Rectangle {
            width: selected.implicitWidth + 8
            height: selected.implicitHeight + 4
            color: root.palette.bright

            Text {
                id: selected

                anchors.centerIn: parent
                text: "SELECTED TEXT READS LIKE THIS"
                color: root.palette.ground
                font.family: Appearance.font.data
                font.pixelSize: 11
                font.weight: Appearance.font.weightSemi
                renderType: Text.NativeRendering
            }
        }

        Row {
            spacing: 8

            KanaTag {
                color: root.palette.signal
                pixelSize: 12
                text: "接続中"
            }

            Text {
                text: "2 PACKAGES PENDING"
                color: root.palette.alert
                font.family: Appearance.font.data
                font.pixelSize: 11
                font.weight: Appearance.font.weightSemi
                renderType: Text.NativeRendering
            }
        }

        Text {
            text: "these are the labels that sit under everything"
            color: root.palette.dim
            font.family: Appearance.font.data
            font.pixelSize: 10
            renderType: Text.NativeRendering
        }
    }
}
