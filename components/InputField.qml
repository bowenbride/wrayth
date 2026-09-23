import QtQuick
import qs.config

// A single-line text field in the shell's styling: a hairline box that takes
// the accent while it has focus, mono type, and a caret that is the accent
// rather than the system's.
//
// Used for the wallpaper folder, hex codes, a profile's name and the cycle
// timings. Each of those wants a different filter, so the caller supplies
// `validator` or handles `edited` -- this does the chrome and the focus.
Item {
    id: root

    property alias text: input.text
    // Whether the user is in this field. The wrapper is an `Item`, so its own
    // `activeFocus` is false while the `TextInput` inside it has the keyboard
    // -- a caller that wants to know has to be told.
    readonly property bool editing: input.activeFocus
    property alias validator: input.validator
    property alias echoMode: input.echoMode
    property alias readOnly: input.readOnly
    property string placeholder: ""
    property int maximumLength: 0
    property color frameColor: input.activeFocus ? Theme.accent : Theme.hair
    property real pixelSize: 11
    property real hPadding: 8

    signal edited(string value)
    signal accepted
    signal escaped

    function take(): void {
        input.forceActiveFocus();
        input.selectAll();
    }

    // Give the keyboard back without touching the text. `OverlayKeys` is
    // watching for exactly this and takes the focus from here.
    function release(): void {
        input.focus = false;
    }

    implicitHeight: 26
    implicitWidth: 160

    Rectangle {
        anchors.fill: parent

        color: input.activeFocus ? Theme.alpha(Theme.accent, 0.06) : Theme.alpha(Theme.hair, 0.22)
        border.width: Appearance.metrics.hairline
        border.color: root.frameColor

        Behavior on border.color {
            ColorAnimation {
                duration: Appearance.duration.state
                easing.type: Easing.OutCubic
            }
        }
    }

    TextInput {
        id: input

        anchors.fill: parent
        anchors.leftMargin: root.hPadding
        anchors.rightMargin: root.hPadding
        verticalAlignment: TextInput.AlignVCenter

        color: Theme.bright
        selectionColor: Theme.alpha(Theme.accent, 0.35)
        selectedTextColor: Theme.bright
        font.family: Appearance.font.data
        font.pixelSize: root.pixelSize
        font.weight: Appearance.font.weightSemi
        renderType: Text.NativeRendering
        clip: true
        maximumLength: root.maximumLength > 0 ? root.maximumLength : 32767

        // The caret is drawn rather than left to the platform, which paints a
        // 1 px black line that vanishes on every one of these grounds.
        cursorDelegate: Rectangle {
            width: 1
            color: Theme.accent
            visible: input.activeFocus
        }

        onTextEdited: root.edited(text)
        onAccepted: root.accepted()
        // **Escape gives the keyboard back.** A field is the one thing allowed
        // to take focus off an overlay's key owner, so it is also the one
        // thing that has to hand it back -- otherwise the surface still holds
        // the keyboard and nothing in it answers Escape. Dropping its own
        // focus is enough: `OverlayKeys` is watching for exactly that.
        Keys.onEscapePressed: event => {
            root.escaped();
            input.focus = false;
            event.accepted = true;
        }
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: root.hPadding
        anchors.verticalCenter: parent.verticalCenter

        visible: !input.text && !input.activeFocus
        text: root.placeholder
        color: Theme.mute
        font.family: Appearance.font.data
        font.pixelSize: root.pixelSize
        renderType: Text.NativeRendering
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.IBeamCursor
        acceptedButtons: Qt.LeftButton
        onPressed: mouse => {
            input.forceActiveFocus();
            mouse.accepted = false;
        }
    }
}
