import QtQuick
import qs.config

// A display title with the design system's chromatic split: a red copy one
// pixel left, a cyan copy one pixel right, both at 55%.
//
// **The split at rest is typography; it has no schedule of its own.** This
// component used to run a 140 ms burst every 4 to 5 seconds, on its own timer,
// on every title independently -- which meant the shell's whole glitch was one
// component's decoration, fired several times a second across a screen with
// several titles on it, and nothing that was not a title ever glitched at all.
// There is one scheduler now: `services/Glitch.qml`, and a title glitches when
// it picks one, wrapped in a `GlitchFx` like anything else.
Item {
    id: root

    property string text: ""
    property real pixelSize: 28
    property int weight: Appearance.font.weightBold
    property color color: Theme.bright
    property color leftColor: Theme.accent
    property color rightColor: Theme.signal

    // **SCRAMBLE writes here, not over `text`.** Assigning to a QML property
    // is the end of whatever binding was on it, and a title like
    // `EDITING // <NAME>` is a binding -- writing junk into it and the old
    // string back would freeze it at whatever it said when the glitch fired.
    // An override is read *instead of* `text` and leaves the binding alone.
    property string scramble: ""

    readonly property string shown: scramble || text

    readonly property real split: 1

    // **Measured from `text`, never from what is drawn.** A scramble writes a
    // different string of the same length, and in a proportional display face
    // that is a different width -- so binding the implicit size to the drawn
    // string would move whatever sits beside the title for the 150 ms the
    // glitch lasts. No animation in this shell changes the size of an element.
    TextMetrics {
        id: metrics

        font: left.font
        text: root.text
    }

    implicitWidth: metrics.advanceWidth + split * 2
    implicitHeight: metrics.height

    Item {
        id: shifted

        anchors.fill: parent

        Text {
            id: left

            x: -root.split
            text: root.shown
            textFormat: Text.PlainText
            color: Theme.alpha(root.leftColor, 0.55)
            font.family: Appearance.font.display
            font.pixelSize: root.pixelSize
            font.weight: root.weight
            renderType: Text.NativeRendering
        }

        Text {
            x: root.split
            text: root.shown
            textFormat: Text.PlainText
            color: Theme.alpha(root.rightColor, 0.55)
            font: left.font
            renderType: Text.NativeRendering
        }

        Text {
            id: main

            text: root.shown
            textFormat: Text.PlainText
            color: root.color
            font: left.font
            renderType: Text.NativeRendering
        }
    }
}
