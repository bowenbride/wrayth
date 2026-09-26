import QtQuick
import qs.config

// A remove mark: Material Symbols Sharp `remove` (DESIGN.md), 14 px. It was
// drawn by hand; `inset` and `thickness` are kept only so callers still load.
Icon {
    property real inset: 0
    property real thickness: 0

    name: "remove"
    size: Tokens.icon.inline
    color: Tokens.color.dim
}
