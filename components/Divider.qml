import QtQuick
import qs.config

// The 1px hair separator between bar readouts.
Rectangle {
    implicitWidth: Tokens.measure.hairline
    implicitHeight: Appearance.metrics.dividerHeight
    color: Tokens.color.hair
}
