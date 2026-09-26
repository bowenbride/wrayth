import QtQuick
import qs.config

// Scrollbar (DESIGN.md): 3 px wide, `track` groove, `dim` thumb, square
// ends, visible only while scrolling or hovered. Place it beside a Flickable
// and give it `view`.
Rectangle {
    id: root

    property Flickable view: null
    readonly property bool needed: view && view.contentHeight > view.height
    readonly property bool active: needed && (view.moving || hover.hovered)

    width: Tokens.measure.scrollbar
    color: Tokens.color.track
    opacity: active ? 1 : 0
    visible: needed

    Behavior on opacity {
        NumberAnimation {
            duration: Tokens.motion.feedback
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.active ? Tokens.motion.easeIn : Tokens.motion.easeOut
        }
    }
    Rectangle {
        width: parent.width
        color: Tokens.color.dim
        height: root.view ? Math.max(Tokens.space.s20, root.height * root.view.height / Math.max(1, root.view.contentHeight)) : 0
        y: root.view ? (root.height - height) * (root.view.contentY / Math.max(1, root.view.contentHeight - root.view.height)) : 0
    }
    HoverHandler {
        id: hover
    }
}
