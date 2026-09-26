import QtQuick
import qs.components
import qs.config

// A label and a row of independent on/off chips -- the effect pool and the
// target groups. It is `EffectsChips` with the one-of-N rule taken out: any
// number of these can be on at once, and each says so on its own.
//
// **Every chip is the width of the widest option**, so the row does not reflow
// as they are switched and no chip is easier to hit than another.
Item {
    id: root

    property string label: ""
    // [{ key, text, on }]
    property var options: []

    signal toggled(string key)

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
                required property var modelData

                pixelSize: 10
                text: modelData.text
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
                required property var modelData

                readonly property bool active: modelData.on

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
                    color: parent.active ? Tokens.color.accent : Tokens.color.mute
                    text: parent.modelData.text

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
                    onTapped: root.toggled(parent.modelData.key)
                }
            }
        }
    }
}
