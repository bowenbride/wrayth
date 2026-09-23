import QtQuick
import qs.config

// Text whose digits occupy identical cells, for fonts with no tabular figures.
// Chakra Petch needs this badly: at 19px its "88:88:88" is 81px wide against
// 52px for "11:11:11", so the clock would lurch every time a digit changed.
Item {
    id: root

    property string text: ""
    property color color: Theme.text
    property font font


    // The widest digit in this font, measured once per font change.
    property real digitWidth: 0

    implicitWidth: row.implicitWidth
    implicitHeight: row.implicitHeight

    TextMetrics {
        id: probe

        font: root.font
    }

    function measure(): void {
        let widest = 0;
        for (let digit = 0; digit <= 9; digit++) {
            probe.text = String(digit);
            widest = Math.max(widest, probe.advanceWidth);
        }
        root.digitWidth = widest;
    }

    onFontChanged: measure()
    Component.onCompleted: measure()


    Row {
        id: row

        anchors.centerIn: parent

        Repeater {
            model: root.text.length

            Item {
                id: cell

                required property int index
                readonly property string character: root.text.charAt(index)
                readonly property bool isDigit: character >= "0" && character <= "9"

                // Digits share a cell; separators keep their natural width.
                width: isDigit ? root.digitWidth : glyph.implicitWidth
                height: glyph.implicitHeight

                Text {
                    id: glyph

                    anchors.centerIn: parent

                    text: cell.character
                    color: root.color
                    font: root.font
                    renderType: Text.NativeRendering
                }
            }
        }
    }
}
