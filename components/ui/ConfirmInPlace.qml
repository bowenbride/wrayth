import QtQuick
import qs.config

// ConfirmInPlace (DESIGN.md): destructive actions. The first activation
// arms it: the label becomes CONFIRM with the action named below it, in
// `accent` (the surface dims everything else to 35% while `armed`). A second
// activation, or `confirm()` from Enter, runs it. Escape (`disarm()`),
// clicking elsewhere, or 4 s idle disarms. It never changes size.
Item {
    id: root

    property string text: ""
    property string action: ""
    property bool armed: false
    signal confirmed

    function activate(): void {
        if (armed) {
            confirm();
            return;
        }
        armed = true;
        idle.restart();
    }
    function confirm(): void {
        if (!armed)
            return;
        armed = false;
        idle.stop();
        confirmed();
    }
    function disarm(): void {
        armed = false;
        idle.stop();
    }

    readonly property var role: Tokens.type.button
    implicitWidth: Math.max(reserve.width, actionReserve.width) + 2 * Tokens.space.s12
    implicitHeight: Tokens.measure.buttonFull + actionLine.implicitHeight + Tokens.space.s4

    TextMetrics {
        id: reserve
        font: label.font
        text: root.text.length > "CONFIRM".length ? root.text : "CONFIRM"
    }
    TextMetrics {
        id: actionReserve
        font: actionLine.font
        text: root.action
    }
    Timer {
        id: idle
        interval: 4000
        onTriggered: root.disarm()
    }

    Rectangle {
        id: frame
        width: parent.width
        height: Tokens.measure.buttonFull
        color: root.armed ? Tokens.color.accentTint : Tokens.color.panelHex
        border.width: Tokens.measure.hairline
        border.color: root.armed ? Tokens.color.accent : Tokens.color.hair

        Text {
            id: label
            anchors.centerIn: parent
            text: root.armed ? "CONFIRM" : root.text
            color: root.armed ? Tokens.color.accent : Tokens.color.text
            font.family: root.role.family
            font.pixelSize: root.role.size
            font.weight: root.role.weight
            font.letterSpacing: root.role.size * root.role.tracking
            textFormat: Text.PlainText
            renderType: Text.NativeRendering
        }
        HoverHandler {
            cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
            onTapped: root.activate()
        }
    }
    Text {
        id: actionLine
        readonly property var role: Tokens.type.hint
        anchors.top: frame.bottom
        anchors.topMargin: Tokens.space.s4
        anchors.horizontalCenter: parent.horizontalCenter
        opacity: root.armed ? 1 : 0
        text: root.action
        color: Tokens.color.accent
        font.family: role.family
        font.pixelSize: role.size
        font.letterSpacing: role.size * role.tracking
        textFormat: Text.PlainText
        renderType: Text.NativeRendering
    }
}
