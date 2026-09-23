import QtQuick
import QtQuick.Shapes
import qs.components
import qs.config

// The last card in the grid: a dashed outline inside the thumbnail area with a
// `+` in it, and the same name row the other cards carry so the row of eight
// keeps one rhythm.
Item {
    id: root

    property bool selected: false

    signal picked

    implicitWidth: 240
    implicitHeight: 214

    readonly property real inset: 10

    // **The cut is derived, not a second constant.** The dashed shape is the
    // card's own outline offset inward by `inset` everywhere, the chamfered
    // diagonal included, so its top-right cut is parallel to the card's and
    // exactly `inset` away from it. Offsetting a 45-degree cut inward by d
    // shortens its leg by d(2 - root 2): at a 16 px chamfer and a 10 px inset
    // the dashed corner cuts 10.14 px, which is what makes the two diagonals
    // read as parallel rather than merely both slanted.
    readonly property real innerChamfer: Appearance.chamfer.panel - inset * (2 - Math.SQRT2)

    property real lift: selected ? -4 : 0

    transform: Translate {
        y: root.lift
    }

    Behavior on lift {
        NumberAnimation {
            duration: Appearance.duration.state
            easing.type: Easing.OutCubic
        }
    }

    ChamferPanel {
        anchors.fill: parent

        chamfer: Appearance.chamfer.panel
        fillColor: root.selected ? Theme.ground : Theme.panel2
        borderColor: root.selected ? Theme.accent : Theme.hair

        Item {
            id: thumb

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 135

            Shape {
                anchors.fill: parent
                // The standing rule: a Shape whose stroke colour is bound to
                // state takes the geometry renderer, which the curve renderer
                // does not repaint for.
                preferredRendererType: Shape.GeometryRenderer

                ShapePath {
                    id: dashed

                    readonly property real left: root.inset
                    readonly property real top: root.inset
                    readonly property real right: thumb.width - root.inset
                    readonly property real bottom: thumb.height - root.inset

                    fillColor: "transparent"
                    strokeColor: root.selected || hover.hovered ? Theme.accent : Theme.hair
                    strokeWidth: Appearance.metrics.hairline
                    strokeStyle: ShapePath.DashLine
                    dashPattern: [4, 4]

                    startX: dashed.left
                    startY: dashed.top

                    PathLine {
                        x: dashed.right - root.innerChamfer
                        y: dashed.top
                    }
                    PathLine {
                        x: dashed.right
                        y: dashed.top + root.innerChamfer
                    }
                    PathLine {
                        x: dashed.right
                        y: dashed.bottom
                    }
                    PathLine {
                        x: dashed.left
                        y: dashed.bottom
                    }
                    PathLine {
                        x: dashed.left
                        y: dashed.top
                    }
                }
            }

            Text {
                anchors.centerIn: parent

                text: "+"
                color: root.selected || hover.hovered ? Theme.accent : Theme.dim
                font.family: Appearance.font.display
                font.pixelSize: 34
                font.weight: Appearance.font.weightBold
                renderType: Text.NativeRendering
            }
        }

        Rectangle {
            id: line

            anchors.top: thumb.bottom
            anchors.left: thumb.left
            anchors.right: thumb.right
            height: 2
            color: Theme.accent
            opacity: root.selected ? 1 : 0.45
        }

        Column {
            anchors.top: line.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 5

            Text {
                text: "NEW CUSTOM"
                color: root.selected ? Theme.accent : Theme.text
                font.family: Appearance.font.display
                font.pixelSize: 14
                font.weight: Appearance.font.weightBold
                renderType: Text.NativeRendering
            }

            Text {
                width: parent.width

                text: "Nine colours of your own. The rest of the palette follows."
                color: Theme.text
                font.family: Appearance.font.data
                font.pixelSize: 10
                wrapMode: Text.Wrap
                renderType: Text.NativeRendering
            }
        }
    }

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: root.picked()
    }
}
