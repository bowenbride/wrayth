import QtQuick
import qs.config

// A single horizontal bar, centred on its ink. The quiet remove control on a
// pool chip: it takes a wallpaper out of one profile and never touches a file,
// so it is a mark rather than a word and it is not on screen at rest.
//
// It is drawn rather than typed for the same reason `CloseGlyph` is: a font's
// `-` is a small mark floating inside its own bearings, and at 18 px it reads
// as a speck sitting wherever the font's metrics put it.
Item {
    id: root

    property color color: Theme.dim
    // Clear air either side of the bar, inside the box.
    property real inset: 4
    property real thickness: 2

    implicitWidth: 18
    implicitHeight: 18

    Rectangle {
        // The bar is the only ink, so centring it is centring the ink. Rounded
        // so a fractional box height cannot land it half a pixel off.
        x: root.inset
        y: Math.round((root.height - root.thickness) / 2)
        width: root.width - root.inset * 2
        height: root.thickness
        color: root.color
    }
}
