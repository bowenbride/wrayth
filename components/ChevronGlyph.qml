import QtQuick
import qs.config

// A chevron, `left` or `right`, from Material Symbols Sharp (chevron_left,
// chevron_right).
Icon {
    property string direction: "right"

    name: direction === "left" ? "chevron_left" : "chevron_right"
    color: Tokens.color.text
    size: 14
}
