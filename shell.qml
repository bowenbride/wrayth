//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1

import Quickshell
import qs.modules.background
import qs.modules.bar
import qs.modules.capture
import qs.modules.clipboard
import qs.modules.deck
import qs.modules.deck.hud
import qs.modules.dropdowns
import qs.modules.notifications
import qs.modules.keybinds
import qs.modules.launcher
import qs.modules.lock
import qs.modules.picker
import qs.modules.polkit
import qs.modules.popups
import qs.modules.session
import qs.modules.status
import qs.services

ShellRoot {
    Background {}
    ScanlineLayer {}
    Bar {}
    Dropdowns {}
    DeckOverlay {}
    NotificationLayer {}
    OsdLayer {}
    LauncherOverlay {}
    SessionOverlay {}
    PickerOverlay {}
    CaptureOverlay {}
    KeybindsOverlay {}
    ClipboardOverlay {}
    DaemonLibrary {}
    LockScreen {}
    PolkitPrompt {}
    StatusCache {}
    FontCheck {}
    ScreenCheck {}
    Ipc {}
}
