import QtQuick
import qs.config

// The 1px hair separator between bar readouts.
Rectangle {
    implicitWidth: Appearance.metrics.hairline
    implicitHeight: Appearance.metrics.dividerHeight
    color: Theme.hair
}
