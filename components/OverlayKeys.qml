import QtQuick
import QtQuick.Window

// The one item in a full-screen overlay that owns the keyboard.
//
// **An overlay holding `WlrKeyboardFocus.Exclusive` owns the whole keyboard.**
// If no item inside it has active focus, every key -- Escape included --
// reaches nothing, and the only way out is killing the shell from a TTY. That
// is not a hypothetical: the profile picker did exactly this, because its key
// handler was switched off with `enabled` while another screen was up and
// nothing gave the focus back when that screen closed.
//
// So this item has three rules, and they are the whole component:
//
//   1. **It is never disabled.** A handler that can be switched off is a
//      handler that can be switched off at the wrong moment. Screens gate
//      their keys *inside* the handler, not by disabling the holder.
//   2. **Nothing inside the overlay competes with it for focus** except a text
//      field the user is actually typing in, which hands focus back when it is
//      done -- see `InputField`.
//   3. **It takes the focus back the instant nothing holds it**, which is the
//      state the trap is made of.
Item {
    id: root

    // The overlay's own visibility.
    required property bool active

    signal escaped

    focus: true

    function take(): void {
        root.forceActiveFocus();
    }

    onActiveChanged: if (active) take()
    Component.onCompleted: if (active) take()

    Keys.onEscapePressed: event => {
        root.escaped();
        event.accepted = true;
    }

    // Who holds the keyboard inside this window. A field that cleared its own
    // focus, a screen hidden while focused, an item disabled under the caret
    // -- each leaves the surface holding the keyboard with nothing to deliver
    // it to.
    //
    // **The holder is almost never null when that happens.** Focus falls back
    // to the window's own root item, which answers no key at all -- measured:
    // cancelling a text field left `activeFocusItem` reading
    // `QQuickRootItem`, so a null check sat there doing nothing while Escape
    // was dead. The test is therefore not "is anything holding it" but "is
    // anything holding it that will *answer*".
    readonly property var holder: root.Window.activeFocusItem

    // The only thing allowed to hold the keyboard instead of this item is a
    // field the user is actually typing in, which gives it back when it is
    // done. Text inputs are recognised by having a caret; nothing else in an
    // overlay does. **The constraint this imposes is deliberate:** inside an
    // overlay, focus belongs either to the key owner or to a text field, and
    // anything else that grabs it will be taken back from within 300 ms.
    function answersKeys(item: var): bool {
        return !!item && (item === root || item.cursorPosition !== undefined);
    }

    // **Deferred by a tick, not taken here.** `take()` changes
    // `activeFocusItem`, which is what `holder` is bound to, so grabbing the
    // focus inside this handler re-enters the binding and Qt reports a loop.
    // It converges either way, but a binding loop costs a frame and hides
    // real ones.
    onHolderChanged: if (root.active && !root.answersKeys(root.holder)) regrab.restart()

    Timer {
        id: regrab

        interval: 1
        onTriggered: root.take()
    }

    // The line above catches every route into that state seen so far. This
    // catches the ones that have not been seen, and turns the worst case into
    // a third of a second of a dead Escape rather than a dead session.
    Timer {
        running: root.active
        interval: 300
        repeat: true
        onTriggered: if (!root.answersKeys(root.Window.activeFocusItem)) root.take()
    }
}
