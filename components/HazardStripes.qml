import QtQuick
import QtQuick.Shapes
import qs.config

// Diagonal hazard stripes, leaning right like ////.
//
// Every stripe is an explicit parallelogram with integer vertices, so its edges
// land on pixel boundaries. Widths are measured along the x axis rather than
// perpendicular to the stripe: at 45 degrees an equal horizontal stripe and gap
// read as equal visual thickness, and keeping the measurement horizontal is what
// keeps the vertices whole. 6 px of stripe on a 12 px pitch gives three stripes
// in the bar's 36 px box and eight in the HUD's 96 px strip.
Item {
    id: root

    property color stripeColor: Theme.accent
    property int period: 12
    property int stripeWidth: 6

    implicitWidth: 58
    implicitHeight: 11
    clip: true

    Shape {
        id: shape

        anchors.fill: parent

        // Straight 45-degree edges alias badly without this; the Shape renders
        // through a multisampled layer so they come out clean rather than soft.
        layer.enabled: true
        layer.samples: 4

        ShapePath {
            fillColor: root.stripeColor
            strokeColor: "transparent"
            strokeWidth: 0

            PathSvg {
                path: {
                    const h = Math.round(root.height);
                    const w = root.stripeWidth;
                    const p = root.period;
                    // The lean puts a stripe's top edge h px right of its bottom
                    // edge, so the run has to start a full lean left of the box
                    // for the bottom-left corner to be covered.
                    const first = -p * (Math.ceil(h / p) + 1);
                    let d = "";
                    for (let x = first; x <= root.width; x += p)
                        d += `M ${x} ${h} L ${x + w} ${h} L ${x + w + h} 0 L ${x + h} 0 Z `;
                    return d;
                }
            }
        }
    }
}
