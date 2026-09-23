import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.components
import qs.config
import qs.services
import qs.modules.picker.mini

// One scanline treatment, rendered rather than described.
//
// **A swatch cannot answer "what does a rolling band look like".** Every tile
// draws the same sample -- a `SYS.DIAG` panel over a blurred wallpaper with
// two lines of terminal text under it -- with its own treatment actually
// applied on top, so choosing between six of them is looking rather than
// reading. The sample is the shell's own furniture for the same reason: what
// the lines do to a hairline border and to 8 px type is the whole question.
Item {
    id: root

    required property var treatment
    required property bool selected

    signal picked

    implicitWidth: 230
    // **228, not 214.** The description ran into the panel's own bottom-left
    // chamfer -- a 16 px diagonal cut, and the last line's left-hand
    // characters were inside it. The block is top-anchored, so the height is
    // what buys the clearance: the text ends 19 px above the bottom edge and
    // the cut starts at 16.
    implicitHeight: 228

    // Selected tiles lift, exactly as the profile cards do. A transform, not a
    // `y` binding: a positioner assigns `y` to its children and a binding on
    // it wins over that assignment.
    property real lift: selected ? -4 : 0

    transform: Translate {
        y: root.lift
    }

    Behavior on lift {
        NumberAnimation {
            duration: Appearance.duration.move
            easing.type: Easing.OutCubic
        }
    }

    ChamferPanel {
        anchors.fill: parent

        chamfer: Appearance.chamfer.panel
        fillColor: root.selected ? Theme.ground : Theme.panel2
        borderColor: root.selected ? Theme.accent : Theme.hair
        // **A preview shows its own treatment and nothing else.** The panel's
        // own overlay would lay whatever the shell is wearing over all six
        // samples at once, which is the one thing a row of previews may not
        // do. Turning it off here also keeps the `MiniDiag` inside from
        // drawing one, because a panel under a panel leaves the lines alone.
        scanlines: false

        Behavior on borderColor {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }

        // --- The sample ----------------------------------------------------
        // **Masked to the panel's own cut corner.** It is a rectangle inside a
        // chamfered panel, so its fill and everything drawn on it painted
        // straight over the diagonal and the border went missing at the
        // top-right of every tile. The mask is the panel's outline offset
        // inward by the 1 px the sample is inset, by the same rule the profile
        // cards' thumbnails use: a 45-degree cut offset inward by d loses
        // d(2 - root 2) of its leg.
        Item {
            id: sample

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 152
            clip: true

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: sampleMask
                maskThresholdMin: 0.5
            }

            Rectangle {
                anchors.fill: parent
                color: Theme.ground
            }

            Wallpaper {
                anchors.fill: parent
                blurRadius: 4
                dim: 0.4
            }

            MiniDiag {
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 8
                anchors.rightMargin: 9
                palette: Theme.palette
            }

            // Two lines of terminal text, which is what the lines are hardest
            // on: a 1 px rule every 3 px across 9 px type is the case that
            // decides whether a treatment is usable.
            Column {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.leftMargin: 9
                anchors.bottomMargin: 9
                spacing: 3

                Text {
                    text: "wrayth ~/deck $"
                    color: Theme.signal
                    font.family: Appearance.font.data
                    font.pixelSize: 9
                    renderType: Text.NativeRendering
                }

                Text {
                    text: "ICE NOMINAL // 25 SERVICES"
                    color: Theme.text
                    font.family: Appearance.font.data
                    font.pixelSize: 9
                    renderType: Text.NativeRendering
                }
            }

            // The treatment itself, over everything the sample draws.
            Scanlines {
                forced: root.treatment.key
            }
        }

        // Drawn at zero opacity rather than hidden: an invisible item never
        // renders into its layer, and an empty mask hides everything.
        Item {
            id: sampleMask

            x: sample.x
            y: sample.y
            width: sample.width
            height: sample.height
            opacity: 0
            layer.enabled: true

            readonly property real cut: Appearance.chamfer.panel - (2 - Math.SQRT2)

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.GeometryRenderer

                ShapePath {
                    fillColor: "white"
                    strokeWidth: 0
                    strokeColor: "transparent"

                    startX: 0
                    startY: 0

                    PathLine {
                        x: sampleMask.width - sampleMask.cut
                        y: 0
                    }
                    PathLine {
                        x: sampleMask.width
                        y: sampleMask.cut
                    }
                    PathLine {
                        x: sampleMask.width
                        y: sampleMask.height
                    }
                    PathLine {
                        x: 0
                        y: sampleMask.height
                    }
                    PathLine {
                        x: 0
                        y: 0
                    }
                }
            }
        }

        Rectangle {
            id: rule

            anchors.top: sample.bottom
            anchors.left: sample.left
            anchors.right: sample.right
            height: 2
            color: root.selected ? Theme.accent : Theme.hair
            opacity: root.selected ? 1 : 0.45

            Behavior on opacity {
                NumberAnimation {
                    duration: Appearance.duration.state
                    easing.type: Easing.OutCubic
                }
            }
        }

        Column {
            anchors.top: rule.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 4

            NrLabel {
                width: parent.width
                color: root.selected ? Theme.accent : Theme.bright
                elide: Text.ElideRight
                text: root.treatment.name
            }

            Text {
                width: parent.width
                text: root.treatment.about
                color: Theme.text
                font.family: Appearance.font.data
                font.pixelSize: 10
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                renderType: Text.NativeRendering
            }
        }
    }

    HoverHandler {
        cursorShape: Qt.PointingHandCursor
    }

    Feedback {
        id: feedback

        anchors.fill: parent
        flashOpacity: 0.22
    }

    TapHandler {
        onPressedChanged: if (pressed) feedback.flash()
        onTapped: defer.restart()
    }

    // One frame between the flash and the work, so the acknowledgement is
    // painted first however long the change then takes.
    Timer {
        id: defer

        interval: 16
        onTriggered: root.picked()
    }
}
