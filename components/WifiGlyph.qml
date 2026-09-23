import QtQuick
import QtQuick.Shapes
import qs.config

// The Wi-Fi strength icon, in place of the `NET` label: four ascending bars
// with their top-right corners cut, so they belong to the same family as the
// panels' chamfers.
//
// **Each bar is its own path**, because each is separately lit: the ones the
// current signal reaches take the data colour and the rest stay the label
// grey the word `NET` used to be.
//
// **It is drawn on a 15 px grid and laid out on a 13 px one.** Four bars
// with 1 px gaps admit only one integer width per box size, and 13 px allows
// nothing thicker than 2 -- which is the version that read as too thin. 15 px
// is the first size where 3 px bars with 1 px gaps fit, and it fits exactly,
// with no slack anywhere. So the figure is 15 wide and the *item* stays 13,
// overflowing a pixel either side into the row's 7 px spacing: the icon gains
// its weight and **nothing on the bar moves**.
//
// **The cut is a step, not a diagonal.** A 45-degree cut across a bar this
// size covers half a pixel, and `Shape.GeometryRenderer` -- which the
// standing rule requires -- has no coverage to give it: measured, the
// diagonal disappeared and every bar came out a plain rectangle. One whole
// pixel out of the top-right corner is the same cut at the only resolution
// this size has.
Item {
    id: root

    // 0..1, as NetworkManager reports it.
    property real strength: 0
    property bool active: false
    property color litColor: Theme.signal
    property color unlitColor: Theme.dim

    // The layout slot. The drawing is wider; see above.
    implicitWidth: 13
    implicitHeight: 15

    readonly property int drawn: 15

    // 4 above 75%, 3 above 50%, 2 above 25%, otherwise 1 -- and nothing lit
    // at all when there is no link to measure.
    readonly property int lit: {
        if (!root.active)
            return 0;
        if (root.strength > 0.75)
            return 4;
        if (root.strength > 0.5)
            return 3;
        if (root.strength > 0.25)
            return 2;
        return 1;
    }

    // Four separate paths, written out rather than repeated: `Repeater` needs
    // an `Item` delegate and a `ShapePath` is not one. Bars 3 wide on a pitch
    // of 4, heights 4, 7, 11 and 14 on a shared baseline at y = 14.
    Shape {
        x: (root.width - root.drawn) / 2
        width: root.drawn
        height: root.drawn
        // The standing rule: a Shape whose fill is bound to state takes the
        // geometry renderer.
        preferredRendererType: Shape.GeometryRenderer

        ShapePath {
            fillColor: root.lit > 0 ? root.litColor : root.unlitColor
            strokeWidth: 0
            strokeColor: "transparent"

            PathSvg {
                path: "M0 10 H2 V11 H3 V14 H0 Z"
            }
        }

        ShapePath {
            fillColor: root.lit > 1 ? root.litColor : root.unlitColor
            strokeWidth: 0
            strokeColor: "transparent"

            PathSvg {
                path: "M4 7 H6 V8 H7 V14 H4 Z"
            }
        }

        ShapePath {
            fillColor: root.lit > 2 ? root.litColor : root.unlitColor
            strokeWidth: 0
            strokeColor: "transparent"

            PathSvg {
                path: "M8 3 H10 V4 H11 V14 H8 Z"
            }
        }

        ShapePath {
            fillColor: root.lit > 3 ? root.litColor : root.unlitColor
            strokeWidth: 0
            strokeColor: "transparent"

            PathSvg {
                path: "M12 0 H14 V1 H15 V14 H12 Z"
            }
        }
    }
}
