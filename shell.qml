//@ pragma DefaultEnv QS_NO_RELOAD_POPUP=1

import Quickshell
import qs.modules.background
import qs.modules.bar
import qs.modules.deck
import qs.modules.deck.hud
import qs.modules.dropdowns
import qs.modules.notifications
import qs.modules.launcher
import qs.modules.lock
import qs.modules.picker
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
    DaemonLibrary {}
    LockScreen {}
    StatusCache {}
    FontCheck {}
    ScreenCheck {}
    Ipc {}
}
