import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import qs.components
import qs.config
import qs.services
import qs.modules.picker.mini

// One profile: a live miniature of the shell in that profile's colours over
// its card image, then the name, its number and its one-line description.
Item {
    id: root

    required property string name
    required property bool selected
    required property bool active

    // The shell's own palette while a card outlives its profile. A card is
    // destroyed a frame after the profile it names is deleted, and for that
    // frame every binding under it would be reading an undefined palette.
    readonly property var palette: Profiles.palettes[root.name] ?? Theme.palette
    readonly property color tone: root.palette.accent
    readonly property bool custom: Profiles.isCustom(root.name)

    // `PROFILE 0N` counts the presets and `CUSTOM 0N` the customs, each from
    // one, so the number means "the Nth of its kind" rather than a position in
    // a list that changes every time a profile is made.
    readonly property string badge: {
        const within = root.custom ? Customs.names.indexOf(root.name) : Profiles.presetNames.indexOf(root.name);
        return `${root.custom ? "CUSTOM" : "PROFILE"} ${String(within + 1).padStart(2, "0")}`;
    }

    // APPLYING while the shell and kitty recolour.
    property bool working: false
    property bool succeeded: false

    // The confirmation is a state of the card, not a dialog somewhere else:
    // it covers the card it is asking about.
    property bool confirming: false

    signal picked
    signal editRequested
    signal deleteRequested
    signal deleteConfirmed
    signal deleteCancelled

    implicitWidth: 240
    implicitHeight: 214

    // Selected cards lift. This has to be a transform, not a `y` binding: a
    // positioner assigns x and y to its children, and a binding on `y` wins
    // over that assignment -- the card left its own cell in the grid and
    // landed on top of the first one.
    property real lift: selected ? -4 : 0

    transform: Translate {
        y: root.lift
    }

    Behavior on lift {
        NumberAnimation {
            duration: Tokens.motion.feedback
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.motion.easeIn
        }
    }

    ChamferPanel {
        anchors.fill: parent

        chamfer: Appearance.chamfer.panel
        fillColor: root.selected ? Tokens.color.ground : Tokens.color.panel2
        borderColor: root.selected ? root.tone : Tokens.color.hair

        // **The thumbnail is masked to the card's own cut corner.** It is a
        // rectangle inside a chamfered panel, so its own fill -- the mini
        // bar's strip, and the image under it -- painted straight over the
        // diagonal and the border went missing at exactly that corner on
        // every card. The mask is the card's outline offset inward by the
        // 1 px the thumbnail is inset, by the same rule the `+ NEW CUSTOM`
        // card's dashed outline uses: a 45-degree cut offset inward by d
        // loses d(2 - root 2) of its leg.
        Item {
            id: thumb

            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 1
            height: 135
            clip: true

            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: thumbMask
                maskThresholdMin: 0.5
            }

            MiniShell {
                anchors.fill: parent
                palette: root.palette
                image: Wallpapers.cardImage(root.name)
                active: root.active
                dimmed: !root.selected
            }

            // Only a custom profile carries these. A preset has no buttons
            // rather than disabled ones: there is no state in which a preset
            // becomes editable or deletable, so greyed buttons would be
            // explaining something that never happens.
            Row {
                anchors.left: parent.left
                anchors.bottom: parent.bottom
                anchors.margins: 6
                visible: root.custom
                spacing: 6

                Repeater {
                    model: [
                        {
                            label: "EDIT",
                            edit: true
                        },
                        {
                            label: "DELETE",
                            edit: false
                        }
                    ]

                    Rectangle {
                        required property var modelData

                        width: buttonLabel.implicitWidth + 18
                        height: 24
                        // Opaque, not a wash: these sit on a photograph, and
                        // at 8 px on a half-transparent backing they could not
                        // be read at all.
                        color: Qt.rgba(0, 0, 0, buttonHover.hovered ? 0.92 : 0.8)
                        border.width: Tokens.measure.hairline
                        border.color: root.tone

                        NrLabel {
                            id: buttonLabel

                            anchors.centerIn: parent
                            centred: true
                            pixelSize: Appearance.size.label
                            color: root.tone
                            text: parent.modelData.label
                        }

                        HoverHandler {
                            id: buttonHover

                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            // Swallowed here, so a click on one of these never
                            // reaches the card underneath and previews the
                            // profile on its way to editing or removing it.
                            gesturePolicy: TapHandler.ReleaseWithinBounds
                            onTapped: {
                                if (parent.modelData.edit)
                                    root.editRequested();
                                else
                                    root.deleteRequested();
                            }
                        }
                    }
                }
            }
        }

        // Drawn at zero opacity rather than `visible: false` -- an invisible
        // item never renders into its layer, so it would hand MultiEffect an
        // empty mask and the thumbnail would vanish.
        Item {
            id: thumbMask

            x: thumb.x
            y: thumb.y
            width: thumb.width
            height: thumb.height
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
                        x: thumbMask.width - thumbMask.cut
                        y: 0
                    }
                    PathLine {
                        x: thumbMask.width
                        y: thumbMask.cut
                    }
                    PathLine {
                        x: thumbMask.width
                        y: thumbMask.height
                    }
                    PathLine {
                        x: 0
                        y: thumbMask.height
                    }
                    PathLine {
                        x: 0
                        y: 0
                    }
                }
            }
        }

        // A 2 px line in the profile's own accent along the thumbnail's bottom.
        Rectangle {
            id: line

            anchors.top: thumb.bottom
            anchors.left: thumb.left
            anchors.right: thumb.right
            height: 2
            color: root.tone
            opacity: root.selected ? 1 : 0.45

            Behavior on opacity {
                NumberAnimation {
                    duration: Tokens.motion.feedback
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Tokens.motion.easeIn
                }
            }
        }

        Column {
            anchors.top: line.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.topMargin: 8
            anchors.leftMargin: 10
            anchors.rightMargin: 10
            spacing: 5

            Item {
                width: parent.width
                height: title.implicitHeight

                Text {
                    id: title

                    text: root.name.toUpperCase()
                    color: root.selected ? root.tone : Tokens.color.text
                    font.family: Tokens.font.display
                    font.pixelSize: 14
                    font.weight: Appearance.font.weightBold
                    renderType: Text.NativeRendering
                }

                NrLabel {
                    anchors.right: parent.right
                    anchors.verticalCenter: title.verticalCenter
                    pixelSize: 10
                    color: Tokens.color.dim
                    text: root.badge
                }
            }

            Text {
                width: parent.width

                text: Profiles.descriptions[root.name] ?? ""
                color: Tokens.color.text
                font.family: Tokens.font.data
                font.pixelSize: 10
                wrapMode: Text.Wrap
                maximumLineCount: 3
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
        working: root.working
        succeeded: root.succeeded
        flashOpacity: 0.22
    }

    WorkSegments {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 8
        running: root.working
        litColor: root.tone
    }

    TapHandler {
        enabled: !root.working && !root.confirming

        onPressedChanged: if (pressed) feedback.flash()
        onTapped: defer.restart()
    }

    Appear {
        anchors.fill: parent
        fills: true
        shown: root.confirming

    DeleteConfirm {
        anchors.fill: parent
        name: root.name

        onConfirmed: root.deleteConfirmed()
        onCancelled: root.deleteCancelled()
    }
    }

    Timer {
        id: defer

        interval: 16
        onTriggered: root.picked()
    }
}
