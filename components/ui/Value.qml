import QtQuick
import qs.config

// Value (DESIGN.md): anything that reflects live state -- device codes,
// speeds, percentages, counts, times. `text`, or `signal` for live data;
// never dim, never label-styled. Tabular figures, so numbers never jitter.
Text {
    property bool bar: false
    property bool live: false
    readonly property var role: bar ? Tokens.type.barValue : Tokens.type.rowName

    color: live ? Tokens.color.signal : Tokens.color.text
    font.family: role.family
    font.pixelSize: role.size
    font.weight: role.weight
    font.letterSpacing: role.size * role.tracking
    font.features: ({ "tnum": 1 })
    textFormat: Text.PlainText
    renderType: Text.NativeRendering
}
