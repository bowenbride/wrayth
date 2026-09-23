import QtQuick
import QtQuick.Effects
import qs.config

// A seamless horizontal marquee. Two copies of the text chase each other so the
// loop has no seam, and the alpha is masked at both ends to fade the text out.
Item {
    id: root

    property string text: ""
    property real speed: Appearance.metrics.tickerSpeed
    property real fade: Appearance.metrics.tickerFade

    readonly property real contentWidth: first.implicitWidth

    Item {
        id: viewport

        anchors.fill: parent
        clip: true

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: mask
            // Without spread the mask is a hard cutoff rather than a ramp.
            maskSpreadAtMin: 1
        }

        Item {
            id: strip

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: first.implicitHeight

            // Scrolls the width of one copy, then loops; the second copy is
            // exactly where the first started, so the seam never shows.
            property real offset: 0

            Text {
                id: first

                x: -strip.offset
                color: Theme.dim
                text: root.text
                font.family: Appearance.font.data
                font.pixelSize: Appearance.size.ticker
                font.letterSpacing: Appearance.size.ticker * Appearance.tickerTracking
                renderType: Text.NativeRendering
            }

            Text {
                id: second

                x: first.x + root.contentWidth
                color: first.color
                text: first.text
                font: first.font
                renderType: Text.NativeRendering
            }

            // Only earns its keep if the line is ever shorter than the viewport,
            // where two copies would leave a gap at the end of a loop.
            Text {
                x: second.x + root.contentWidth
                visible: root.contentWidth < root.width
                color: first.color
                text: first.text
                font: first.font
                renderType: Text.NativeRendering
            }
        }
    }

    NumberAnimation {
        id: scroll

        target: strip
        property: "offset"
        from: 0
        to: root.contentWidth
        duration: Math.max(1, root.contentWidth / root.speed * 1000)
        loops: Animation.Infinite
        running: root.contentWidth > 0
    }

    // Restart when the content changes length, so the speed stays constant.
    onContentWidthChanged: {
        if (contentWidth > 0)
            scroll.restart();
    }

    // Drawn at zero opacity rather than visible: false -- an invisible item
    // never renders into its layer, so it would hand MultiEffect an empty mask.
    Item {
        id: mask

        anchors.fill: parent
        opacity: 0
        layer.enabled: true

        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: Math.min(0.5, root.fade / Math.max(1, root.width))
                    color: "white"
                }
                GradientStop {
                    position: Math.max(0.5, 1 - root.fade / Math.max(1, root.width))
                    color: "white"
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }
    }
}
