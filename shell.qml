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
import qs.modules.overview
import qs.modules.switcher
import qs.modules.record
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
    // Optional (SYSTEM page, WINDOWS): nothing is loaded while they are off.
    LazyLoader {
        active: SystemSettings.overview
        OverviewOverlay {}
    }
    LazyLoader {
        active: SystemSettings.switcher
        WindowSwitcher {}
    }
    RecordPanel {}
    ClipboardOverlay {}
    DaemonLibrary {}
    LockScreen {}
    LockPreview {}
    PolkitPrompt {}
    StatusCache {}
    FontCheck {}
    ScreenCheck {}
    Ipc {}
}
