import QtQuick
import QtQuick.Shapes
import qs.config

// A Material Symbols (Sharp) icon, by name (config/Icons.qml), filled with a
// profile colour. Square corners throughout: the Sharp style has no rounded
// ends or indents. `size` is the icon's box; the glyph fills it as the set
// draws it at 24 px.
Item {
    id: root

    property string name: ""
    property color color: Theme.dim
    property real size: 16

    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.GeometryRenderer
        visible: (Icons.paths[root.name] ?? "") !== ""

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillColor: root.color
            scale: Qt.size(root.width / 960, root.height / 960)

            PathSvg {
                path: Icons.paths[root.name] ?? ""
            }
        }
        // The set's box runs from -960 to 0 on y.
        transform: Translate {
            y: root.height
        }
    }
}
