import QtQuick
import qs.config

// A media transport icon: "previous", "next", "play" or "pause", from
// Material Symbols Sharp (skip_previous, skip_next, play_arrow, pause).
Icon {
    property string kind: "play"

    name: ({ previous: "skip_previous", next: "skip_next", play: "play_arrow", pause: "pause" })[kind] ?? "play_arrow"
    color: Tokens.color.text
    size: 16
}
