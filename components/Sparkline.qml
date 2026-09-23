import QtQuick
import QtQuick.Shapes
import qs.config

// Two series over a shared vertical scale: download in signal, upload in accent.
// The bar draws 12 points at 48x16; the HUD draws 13 at 376x48.
Item {
    id: root

    property var downValues: []
    property var upValues: []
    property color downColor: Theme.signal
    property color upColor: Theme.accent
    property int points: 12
    property real strokeWidth: 1

    // Keeps an idle link flat instead of amplifying a few bytes of noise.
    property real floorValue: 16 * 1024

    implicitWidth: 48
    implicitHeight: 16

    readonly property real scale: {
        let peak = floorValue;
        for (const value of downValues.concat(upValues))
            peak = Math.max(peak, value);
        return peak;
    }

    function _path(values: var): var {
        const path = [];
        // Right-align the series, so a short history draws from the right edge.
        const start = Math.max(0, values.length - points);
        const used = values.slice(start);
        const step = points > 1 ? width / (points - 1) : 0;
        const offset = points - used.length;
        for (let i = 0; i < used.length; i++) {
            const y = height - Math.min(1, used[i] / scale) * (height - strokeWidth) - strokeWidth / 2;
            path.push(Qt.point((offset + i) * step, y));
        }
        return path;
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: root.downColor
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: root._path(root.downValues)
            }
        }

        ShapePath {
            strokeColor: root.upColor
            strokeWidth: root.strokeWidth
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: root._path(root.upValues)
            }
        }
    }
}
