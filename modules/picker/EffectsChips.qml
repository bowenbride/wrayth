import QtQuick
import qs.components
import qs.config

// One setting as a row of chips: a label, then one chip per option, the
// current one in accent. The pools screen's `MODE` toggle is the same control,
// which is the point -- the shell has one way of saying "one of these".
//
// **Every chip is the width of the widest option**, so the row does not
// reflow when the choice moves and no chip is easier to hit than another.
Item {
    id: root

    property string label: ""
    property var options: []
    property string current: ""

    signal chosen(string option)

    // The label's slot, so a row underneath can line its own controls up with
    // this one's rather than with its words.
    readonly property real labelWidth: heading.implicitWidth

    implicitWidth: heading.implicitWidth + 10 + chips.implicitWidth
    implicitHeight: Math.max(heading.implicitHeight, chips.implicitHeight)

    NrLabel {
        id: heading

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        color: Tokens.color.dim
        text: root.label
    }

    // The widest option's width, measured by the component that draws them.
    Column {
        id: reserve

        visible: false

        Repeater {
            model: root.options

            NrLabel {
                required property string modelData

                pixelSize: 10
                text: modelData
            }
        }
    }

    Row {
        id: chips

        anchors.left: heading.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        Repeater {
            model: root.options

            Rectangle {
                required property string modelData

                readonly property bool active: root.current === modelData

                width: reserve.implicitWidth + 16
                height: 22
                color: active ? Theme.alpha(Tokens.color.accent, 0.18) : hover.hovered ? Theme.alpha(Tokens.color.hair, 0.3) : "transparent"
                border.width: Tokens.measure.hairline
                border.color: active ? Tokens.color.accent : Tokens.color.hair

                Behavior on color {
                    ColorAnimation {
                        duration: Tokens.motion.feedback
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.motion.easeIn
                    }
                }

                Behavior on border.color {
                    ColorAnimation {
                        duration: Tokens.motion.feedback
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Tokens.motion.easeIn
                    }
                }

                NrLabel {
                    anchors.fill: parent
                    centred: true
                    horizontalAlignment: Text.AlignHCenter
                    pixelSize: 10
                    color: parent.active ? Tokens.color.accent : Tokens.color.text
                    text: parent.modelData

                    Behavior on color {
                        ColorAnimation {
                            duration: Tokens.motion.feedback
                            easing.type: Easing.BezierSpline
                            easing.bezierCurve: Tokens.motion.easeIn
                        }
                    }
                }

                HoverHandler {
                    id: hover

                    cursorShape: Qt.PointingHandCursor
                }

                Feedback {
                    id: feedback

                    anchors.fill: parent
                    flashOpacity: 0.3
                }

                TapHandler {
                    onPressedChanged: if (pressed) feedback.flash()
                    onTapped: root.chosen(parent.modelData)
                }
            }
        }
    }
}
