import QtQuick
import qs.components
import qs.config
import qs.services

// A whole number of seconds, staged rather than applied.
//
// **Typing does not change the schedule.** The field holds what was typed and
// says so; `APPLY` beside it is what commits, and validation happens there --
// on the whole set at once, because `FROM` and `TO` are only right or wrong
// together. The old field clamped silently on every keystroke, which corrected
// numbers under the user's hands while they were still typing them.
//
// **Escape leaves the field and keeps what was typed.** It used to throw the
// value away, which is the opposite of what a staging field is for.
Item {
    id: root

    // What is stored, for comparison and for resetting.
    property int committed: 0
    // What is typed. The host owns it, so `APPLY` can read every field at once.
    property alias text: field.text

    readonly property bool editing: field.editing
    readonly property bool dirty: `${root.committed}` !== field.text.trim()

    signal accepted

    function sync(): void {
        field.text = `${root.committed}`;
    }

    function release(): void {
        field.release();
    }

    onCommittedChanged: if (!field.editing) sync()
    Component.onCompleted: sync()

    implicitWidth: 62
    implicitHeight: field.implicitHeight

    InputField {
        id: field

        anchors.fill: parent
        pixelSize: 11
        // Digits only, and no upper bound here: 3600 is a rule about the value,
        // which `APPLY` enforces and can explain. A validator that refuses the
        // keystroke cannot say why.
        validator: RegularExpressionValidator {
            regularExpression: /[0-9]{0,5}/
        }
        // Staged changes are the accent, so a field that has been touched and
        // not applied says so on its own as well as through the button.
        // `editing`, not `activeFocus`: the wrapper is an Item whose own
        // activeFocus is always false, so the focused frame never showed.
        frameColor: field.editing ? Theme.accent : root.dirty ? Theme.alpha(Theme.accent, 0.7) : Theme.hair

        onAccepted: root.accepted()
        // **Escape keeps the text.** It only gives the keyboard back.
        onEscaped: {}
    }
}
