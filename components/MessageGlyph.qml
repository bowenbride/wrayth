import QtQuick
import QtQuick.Shapes
import qs.config

// A speech bubble, ours rather than any chat client's logo: 18 x 14, one path,
// even-odd filled so the three "typing" dots are **cut out of** the body
// instead of drawn on top of it. That is what keeps them the ground colour
// behind the bar rather than a second colour to keep in step, and what keeps
// them crisp when the bubble changes colour.
//
// The top-right corner is cut and the tail is hard-edged at the bottom left,
// so it belongs to the same family as the panels.
Item {
    id: root

    property color color: Theme.dim

    implicitWidth: 18
    implicitHeight: 14

    Shape {
        anchors.fill: parent
        // The standing rule: a Shape whose fill is bound to state takes the
        // geometry renderer.
        preferredRendererType: Shape.GeometryRenderer

        ShapePath {
            fillColor: root.color
            fillRule: ShapePath.OddEvenFill
            strokeWidth: 0
            strokeColor: "transparent"

            // **The dots are on whole pixels, and the body is as specified.**
            // At 2.2 px square on fractional offsets -- 3.5, 7.9, 12.3 -- the
            // three came out 3, 2 and 2 pixels wide, measured on the bar:
            // uneven slots rather than three dots. Snapped to 2 x 2 at x 4, 8
            // and 12 they keep the same centres and the same 4 px rhythm, and
            // every edge lands on a pixel boundary.
            PathSvg {
                path: "M0 0 H15 L18 3 V11 H6.5 L3 14 V11 H0 Z" + " M4 5 H6 V7 H4 Z" + " M8 5 H10 V7 H8 Z" + " M12 5 H14 V7 H12 Z"
            }
        }
    }
}
