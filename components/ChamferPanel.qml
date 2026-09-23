import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.config

// A panel with cut corners instead of rounded ones. The default is the design
// system's top-right and bottom-left; each corner is separable because the deck
// interlocks its panels' cuts and a notification has to match the window corner
// it sits inside. Fill plus a 1px hairline frame drawn as one shape.
Item {
    id: root

    property real chamfer: Appearance.chamfer.panel
    // The four corners, each in px. The default pair carries `chamfer`; set any
    // of them to 0 for a square corner.
    property real chamferTopLeft: 0
    property real chamferTopRight: chamfer
    property real chamferBottomRight: 0
    property real chamferBottomLeft: chamfer
    property color fillColor: Theme.panel2
    property color borderColor: Theme.hair
    property real borderWidth: Appearance.metrics.hairline

    // Inset by half the stroke so the hairline sits inside the bounds rather
    // than straddling them.
    readonly property real inset: borderWidth / 2
    readonly property real innerRight: width - inset
    readonly property real innerBottom: height - inset

    default property alias content: holder.data

    // --- Scanlines ---------------------------------------------------------
    // **One overlay per surface, which means one per *outermost* panel.**
    // Every `ChamferPanel` carried its own, so a panel inside a panel drew the
    // pattern twice and a treatment set to 22% came out at 39: measured on a
    // profile card's mini `SYS.DIAG`, a 42.2% drop against 24.5% on a panel
    // with nothing over it. A panel with a panel above it in the tree leaves
    // the lines to that one.
    //
    // Set `scanlines: false` on a panel whose subtree draws its own -- the
    // EFFECTS page's preview tiles, which each show a treatment that is not
    // the one the shell is wearing.
    property bool scanlines: true

    readonly property bool isChamferPanel: true

    property bool nested: false

    Component.onCompleted: {
        // Any panel ancestor at all, drawing or not: the outermost one is the
        // only one entitled to decide, and a preview tile's subtree must stay
        // clear of the setting whatever it is.
        let above = root.parent;
        while (above) {
            if (above.isChamferPanel === true) {
                root.nested = true;
                return;
            }
            above = above.parent;
        }
    }

    Shape {
        anchors.fill: parent
        // **GeometryRenderer, not CurveRenderer.** The curve renderer does not
        // repaint when `strokeColor` changes -- the fill and any child text
        // followed a colour change while the border stayed on its old colour,
        // which left every deselected input in the ident editor still wearing
        // its accent outline and kept APPLY looking enabled while it was not.
        // This path has no curves in it at all, only PathLines, so the curve
        // renderer was buying nothing: the two are pixel-identical on a
        // chamfer, checked side by side at 6x.
        preferredRendererType: Shape.GeometryRenderer

        ShapePath {
            fillColor: root.fillColor
            strokeColor: root.borderColor
            strokeWidth: root.borderWidth

            startX: root.inset + root.chamferTopLeft
            startY: root.inset

            PathLine {
                x: root.innerRight - root.chamferTopRight
                y: root.inset
            }
            PathLine {
                x: root.innerRight
                y: root.inset + root.chamferTopRight
            }
            PathLine {
                x: root.innerRight
                y: root.innerBottom - root.chamferBottomRight
            }
            PathLine {
                x: root.innerRight - root.chamferBottomRight
                y: root.innerBottom
            }
            PathLine {
                x: root.inset + root.chamferBottomLeft
                y: root.innerBottom
            }
            PathLine {
                x: root.inset
                y: root.innerBottom - root.chamferBottomLeft
            }
            PathLine {
                x: root.inset
                y: root.inset + root.chamferTopLeft
            }
            PathLine {
                x: root.inset + root.chamferTopLeft
                y: root.inset
            }
        }
    }

    Item {
        id: holder

        anchors.fill: parent
    }

    // --- Scanlines ------------------------------------------------------------
    // **Every panel in the shell carries them here**, which is what makes "one
    // overlay layer per surface" true rather than a thing each panel remembers
    // -- and it is why the coverage setting can say `PANELS ONLY` and mean it.
    //
    // **Masked to the panel's own cut corner.** The overlay is a rectangle and
    // the panel is not: unmasked, the lines carried on past the chamfer and
    // floated over the blurred desktop in two 16 px triangles on every panel.
    // The layer only exists while the lines are actually drawn, so a shell with
    // scanlines off pays nothing for this at all.
    Item {
        id: lines

        anchors.fill: parent
        // **The opacity, not the child's `visible`.** An item's effective
        // visibility includes its parents', so `visible: overlay.visible`
        // was a loop that settled at false and the overlay never drew once.
        // Opacity does not propagate, so it can be asked.
        visible: overlay.opacity > 0
        layer.enabled: overlay.opacity > 0
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: outline
            maskThresholdMin: 0.5
        }

        Scanlines {
            id: overlay

            surface: "panel"
            active: root.scanlines && !root.nested
        }
    }

    // Drawn at zero opacity rather than hidden: an invisible item never renders
    // into its layer, and an empty mask hides everything it is given.
    Item {
        id: outline

        anchors.fill: parent
        opacity: 0
        visible: overlay.opacity > 0
        layer.enabled: overlay.opacity > 0

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.GeometryRenderer

            ShapePath {
                fillColor: "white"
                strokeWidth: 0
                strokeColor: "transparent"

                startX: root.chamferTopLeft
                startY: 0

                PathLine {
                    x: root.width - root.chamferTopRight
                    y: 0
                }
                PathLine {
                    x: root.width
                    y: root.chamferTopRight
                }
                PathLine {
                    x: root.width
                    y: root.height - root.chamferBottomRight
                }
                PathLine {
                    x: root.width - root.chamferBottomRight
                    y: root.height
                }
                PathLine {
                    x: root.chamferBottomLeft
                    y: root.height
                }
                PathLine {
                    x: 0
                    y: root.height - root.chamferBottomLeft
                }
                PathLine {
                    x: 0
                    y: root.chamferTopLeft
                }
                PathLine {
                    x: root.chamferTopLeft
                    y: 0
                }
            }
        }
    }
}
