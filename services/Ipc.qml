import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import qs.config
import qs.services

// IPC surface: `qs -c wrayth ipc call <target> <function> [args]`.
// The overlay targets are wired to ShellState now and gain their UI in later
// steps, so binds and hypridle can be pointed here once and left alone.
Scope {
    id: root

    IpcHandler {
        target: "launcher"

        function toggle(): void {
            ShellState.openExclusive(ShellState.launcherOpen ? "" : "launcher");
        }
        function open(): void {
            ShellState.openExclusive("launcher");
        }
        function close(): void {
            ShellState.launcherOpen = false;
        }
    }

    IpcHandler {
        target: "power"

        function toggle(): void {
            ShellState.openExclusive(ShellState.powerOpen ? "" : "power");
        }
        function open(): void {
            ShellState.openExclusive("power");
        }
        function close(): void {
            ShellState.powerOpen = false;
        }
    }

    IpcHandler {
        target: "picker"

        function toggle(): void {
            ShellState.openExclusive(ShellState.pickerOpen ? "" : "picker");
        }
        function open(): void {
            ShellState.openExclusive("picker");
        }
        function close(): void {
            ShellState.pickerOpen = false;
        }

        // One of the custom editor's nine, by token name. The editor has to be
        // open -- `picker view editor` first -- because this is the same call
        // its own colour picker makes and there is nothing to make it into
        // otherwise.
        function colour(key: string, hex: string): string {
            if (ShellState.pickerView !== "editor" || !ShellState.pickerOpen)
                return "the custom editor is not open; `picker view editor` first";
            if (!Customs.roles.some(role => role.key === key))
                return `unknown token ${key}; one of ${Customs.roles.map(r => r.key).join(", ")}`;
            const clean = String(hex).trim().toLowerCase();
            if (!/^#[0-9a-f]{6}$/.test(clean))
                return `${hex} is not a #rrggbb colour`;
            ShellState.editorColour(key, clean);
            return `${key} ${clean}`;
        }

        // **Moves the selection, which is what a preview actually is here.**
        // `profile preview` recolours the shell and leaves the grid sitting
        // on whatever card it opened on; this lifts the card too, which is
        // what the picker does under an arrow key. `new` lands on the
        // `+ NEW CUSTOM` card at the end of the grid.
        function select(name: string): string {
            if (!ShellState.pickerOpen)
                return "the picker is not open; `picker open` first";
            if (name !== "new" && !Profiles.resolve(name))
                return `unknown profile ${name}`;
            ShellState.pickerSelect(name);
            return name;
        }

        // Saves the open editor under a name -- the same call its own
        // NAME // PROFILE prompt makes, validated the same way.
        function save(name: string): string {
            if (ShellState.pickerView !== "editor" || !ShellState.pickerOpen)
                return "the custom editor is not open; `picker view editor` first";
            const trimmed = String(name).trim();
            if (!trimmed)
                return "save <name>";
            if (!/^[A-Za-z0-9 -]+$/.test(trimmed))
                return "letters, numbers, spaces and hyphens only";
            if (Profiles.names.some(existing => existing.toLowerCase() === trimmed.toLowerCase()))
                return `${trimmed} is already a profile`;
            ShellState.editorSave(trimmed);
            return trimmed;
        }

        // **Not scaffolding.** The editor, the pools and the effects page are
        // reached by clicking, and a recording has no pointer -- this is the
        // only way to put one of them on screen without one.
        function view(name: string): string {
            if (["grid", "editor", "pools", "effects"].indexOf(name) < 0)
                return `unknown view ${name}`;
            ShellState.pickerEditing = "";
            ShellState.pickerView = name;
            return name;
        }
    }

    // TEMPORARY (QA): the library opens on a click of the HUD heading and
    // `ydotoold` is not running, so this is how a test reaches it.
    IpcHandler {
        target: "daemons"

        function library(state: string): void {
            if (state === "open")
                ShellState.openExclusive("daemons");
            else
                Daemons.libraryOpen = false;
        }

        function expand(id: string): void {
            Daemons.expanded = id;
        }
    }

    // **Not scaffolding any more.** The dropdowns are click-only by design,
    // which nothing in a test or a recording can drive, and both of those are
    // reasons to have a way in that is not the pointer. It validates the name
    // now: setting `dropdown` to something no panel answers to left `overlay
    // state` reporting a dropdown that was not on screen.
    readonly property var dropdownNames: ["ident", "wifi", "bluetooth", "power"]

    // Shared by `demo drag` and `demo dragFile`; see the note on them.
    function runDemoDrag(profile: string, file: string): string {
        if (!Demo.active)
            return "demo mode is not on";
        if (ShellState.pickerView !== "pools" || !ShellState.pickerOpen)
            return "the pools screen is not open; `picker view pools` first";
        const target = Profiles.resolve(profile);
        if (!target)
            return `unknown profile ${profile}`;
        // An empty file lets the pools screen choose against its own draft,
        // which is the only place a previous drag in the same visit shows up.
        ShellState.poolsDemoDrag(file, target);
        return file ? `${file} -> ${target}` : `-> ${target}`;
    }

    IpcHandler {
        target: "dropdown"

        function open(name: string): string {
            if (root.dropdownNames.indexOf(name) < 0)
                return `unknown dropdown ${name}; one of ${root.dropdownNames.join(", ")}`;
            // Under the readout that owns it, so the panel hangs where a
            // click would have put it rather than in the middle of the bar.
            ShellState.dropdownAnchorX = ShellState.anchorFor(name);
            ShellState.dropdown = name;
            return name;
        }
        function close(): void {
            ShellState.dropdown = "";
        }
        function state(): string {
            return ShellState.dropdown || "none";
        }
    }

    // TEMPORARY (QA): drives the shared interaction states so the frame bursts
    // can photograph each one. Paired with ShellState.qaAction.
    IpcHandler {
        target: "qa"

        function action(kind: string): string {
            ShellState.qaAction(kind);
            return kind;
        }

        // TEMPORARY (QA). The glitch schedule is 30 to 90 seconds and its
        // targets are picked at random, so nothing in a test session can make
        // a chosen element glitch with a chosen set of effects -- and a frame
        // burst of a 150 ms effect cannot be aimed at a random one.
        //
        //   glitch fire <key> [effects] [duration]
        //   glitch keys
        //   glitch tick            -- one idle roll, right now
        function fire(key: string, effects: string, duration: string): string {
            const names = effects ? effects.toUpperCase().split(",") : null;
            const options = {};
            if (names)
                options.effects = names;
            if (duration)
                options.duration = parseInt(duration);
            Glitch.fire(key, Object.keys(options).length ? options : null);
            return `${key} ${JSON.stringify(options)}`;
        }

        function keys(): string {
            return Glitch.targets.map(fx => `${fx.key || "-"}${fx.eligible ? "" : " (not eligible)"}${fx.canScramble ? " [text]" : ""}`).join("\n");
        }

        function tick(): string {
            const before = Glitch.running.length;
            Glitch.tick(true);
            // **Against the count, not against `busy`.** `busy` is now a
            // comparison with the overlap limit, so at `ANY` it is never true
            // and every fired glitch was reported as "nothing eligible".
            return Glitch.running.length > before ? `fired on ${Glitch.current?.key || "-"}` : "nothing eligible";
        }

        // TEMPORARY (QA): the EFFECTS page's own PREVIEW button, which nothing
        // in a test session can click.
        function preview(): string {
            return Glitch.preview();
        }
    }

    // **Real, not scaffolding.** The glitch scheduler picks its own target at
    // its own time, which is right for atmosphere and useless for a recording
    // or a demonstration -- "fire one on the SYS.DIAG header, now" has no
    // other way in. `qa fire` stays where it is; that one exists to drive the
    // scheduler's internals and takes effects and durations with it.
    // The deck, so a script has one way in rather than reaching past the
    // shell to Hyprland for the one overlay the shell itself owns the state of.
    // Read-only: the planner's cleared/total, exactly what its header shows.
    // For tests (the nested install test checks a new account starts at 0/0).
    IpcHandler {
        target: "planner"

        function state(): string {
            return `${Planner.done}/${Planner.total}`;
        }
    }

    IpcHandler {
        target: "deck"

        function open(): string {
            Deck.setOpen(true);
            return "open";
        }

        function close(): string {
            Deck.setOpen(false);
            return "closed";
        }

        function toggle(): string {
            Deck.toggle();
            return "toggled";
        }

        function state(): string {
            return Deck.visible ? "open" : "closed";
        }
    }

    IpcHandler {
        target: "glitch"

        // The element's registered key: `diag`, `id`, `ice`, `vuln`,
        // `panel:signal`, `panel:planner`, `panel:vuln`, `lock`.
        function fire(key: string): string {
            if (!key)
                return "fire <key>; see `glitch keys`";
            const target = Glitch.targets.find(fx => fx.key === key);
            if (!target)
                return `no target named ${key}`;
            if (!target.eligible)
                return `${key} is not on screen`;
            Glitch.fire(key, null);
            return key;
        }

        // Every element that can glitch, and whether it is on screen now.
        function keys(): string {
            const named = Glitch.targets.filter(fx => fx.key);
            if (!named.length)
                return "none registered";
            return named.map(fx => `${fx.key}${fx.eligible ? "" : " (not on screen)"}`).join("\n");
        }

        // The whole schedule, so a recording is not interrupted by a glitch
        // it did not ask for. Demo mode does this for itself; this is the
        // manual lever.
        function schedule(state: string): string {
            if (state === "off" || state === "on")
                Glitch.suppressed = state === "off";
            else if (state !== "")
                return "schedule takes on or off";
            return Glitch.suppressed ? "off" : "on";
        }
    }

    // The atmosphere settings. The EFFECTS page's treatment tiles are
    // `TapHandler`s, so this is the only way to change one without a pointer
    // -- and it is the same call the tile makes, `Effects.setScanlines`, so
    // the page follows along as it would under a click.
    IpcHandler {
        target: "effects"

        function scanlines(key: string): string {
            if (!key)
                return `scanlines <key>; one of ${Effects.treatments.map(t => t.key).join(", ")}`;
            if (!Effects.treatments.some(t => t.key === key))
                return `unknown treatment ${key}; one of ${Effects.treatments.map(t => t.key).join(", ")}`;
            Effects.setScanlines(key);
            return key;
        }

        function state(): string {
            // `scanlines` is the user's stored setting; `showing` is what is
            // on screen, which demo mode overrides without touching the file.
            return `scanlines=${Effects.scanlines} showing=${Effects.treatment.key} over=${Effects.scanlinesOver} glitch=${Effects.glitch}`;
        }
    }

    // A notification the shell raises itself, for a scripted moment. It goes
    // out over D-Bus like anyone else's and takes the ordinary card, timer
    // and dismiss behaviour.
    IpcHandler {
        target: "notify"

        function send(summary: string, body: string, app: string, urgency: string): string {
            if (!summary)
                return "send <summary> [body] [app] [urgency]";
            Notifications.sendDemo(summary, body, app, urgency);
            return summary;
        }
    }

    // Demo mode. See `services/Demo.qml` for what it masks and why, and for
    // the watchdog that stops a crashed recorder leaving it on.
    IpcHandler {
        target: "demo"

        function on(seconds: string): string {
            Demo.begin(parseInt(seconds) || 0);
            return `on, expiring in ${Demo.expirySeconds}s without a ping`;
        }

        function off(): string {
            Demo.end();
            return "off";
        }

        // The heartbeat. Without one the watchdog restores everything.
        function ping(): string {
            if (!Demo.active)
                return "not active";
            Demo.ping();
            return "ok";
        }

        // **The one gesture this shell has that a recording cannot make.**
        // The pools screen is built around dragging a wallpaper onto a
        // profile's row, and there is no pointer in a video -- so the shell
        // animates it: the tile lifts, travels an eased arc with a tilt that
        // settles on arrival, the row lights as it comes in, and the drop is
        // the same `addTo` a real release makes. It ends in the draft, which
        // is exactly where a pointer drag ends.
        //
        // **Two functions, not one with an optional argument.** Quickshell's
        // IPC requires every declared parameter, so `drag <profile>` with a
        // defaulted `file` is refused before it reaches the handler.
        function drag(profile: string): string {
            return root.runDemoDrag(profile, "");
        }

        // `file` is a library path relative to the wallpaper folder.
        function dragFile(profile: string, file: string): string {
            return root.runDemoDrag(profile, file);
        }

        // Force the message indicator: `unread`, `read` or `off`.
        function messages(state: string): string {
            return Demo.forceMessages(state);
        }

        function state(): string {
            return `active=${Demo.active} glitchSuppressed=${Glitch.suppressed} messagesForced=${Demo.messagesForced} unread=${Demo.messagesUnread} expiry=${Demo.expirySeconds}s`;
        }
    }

    // Real controls, not scaffolding: each of these is a thing worth binding a
    // key to, and each is the same call the picker's own buttons make.
    IpcHandler {
        target: "wallpaper"

        function dynamic(state: string): string {
            if (state === "toggle")
                Wallpapers.setDynamic(!Wallpapers.dynamic);
            else if (state === "on" || state === "off")
                Wallpapers.setDynamic(state === "on");
            else
                return `dynamic takes on, off or toggle`;
            return Wallpapers.dynamic ? "on" : "off";
        }

        // The next wallpaper in the active profile's rotation, now rather than
        // when the timer comes round.
        function next(): string {
            Wallpapers.advance(Theme.activeProfile);
            return Wallpapers.displayedPath;
        }

        function current(): string {
            return Wallpapers.displayedPath;
        }

        function folder(path: string): string {
            if (path)
                Wallpapers.setFolder(path);
            return Wallpapers.folder || "unset";
        }

        // Creates the folder if it is missing, then opens it in the file
        // manager -- the same call `OPEN FOLDER` makes.
        function open(): string {
            if (!Wallpapers.folder)
                return "no folder set";
            Wallpapers.openFolder();
            return Wallpapers.folder;
        }

        function regenerate(profile: string): string {
            const name = Profiles.resolve(profile) || profile;
            if (!Profiles.palettes[name])
                return `unknown profile ${profile}`;
            Wallpapers.generate(name, null);
            return `${Wallpapers.wraythFolder}/${Wallpapers.generatedName(name)}`;
        }

        function restore(profile: string): string {
            const name = Profiles.resolve(profile) || profile;
            if (!Profiles.palettes[name])
                return `unknown profile ${profile}`;
            const from = Wallpapers.restoreSource();
            if (!from)
                return "no base left to restore from";
            Wallpapers.restore(name);
            return `restoring from ${from.file}`;
        }
    }

    // The recovery hatch. If an overlay ever holds the keyboard and stops
    // answering it, this closes every one of them and drops the grabs with
    // them -- `keyboardFocus` is bound to each overlay's own visibility. It
    // exists so that the answer to a stuck overlay is never "log in on a TTY
    // and kill the shell", which is what it was once.
    IpcHandler {
        target: "overlay"

        function release(): string {
            const was = [];
            if (ShellState.launcherOpen)
                was.push("launcher");
            if (ShellState.powerOpen)
                was.push("power");
            if (ShellState.pickerOpen)
                was.push("picker");
            if (Daemons.libraryOpen)
                was.push("daemons");
            if (ShellState.dropdown)
                was.push(`dropdown:${ShellState.dropdown}`);
            // `closeAll` covers every overlay and the dropdown; the two
            // lines after it put the picker back to the screen it opens on,
            // so a release from inside the editor does not come back into it.
            ShellState.closeAll();
            ShellState.pickerView = "grid";
            ShellState.pickerEditing = "";
            return was.length ? `released ${was.join(" ")}` : "nothing was open";
        }

        function state(): string {
            const up = [];
            if (ShellState.launcherOpen)
                up.push("launcher");
            if (ShellState.powerOpen)
                up.push("power");
            if (ShellState.pickerOpen)
                up.push(`picker:${ShellState.pickerView}`);
            if (Daemons.libraryOpen)
                up.push("daemons");
            if (ShellState.dropdown)
                up.push(`dropdown:${ShellState.dropdown}`);
            if (ShellState.locked)
                up.push("locked");
            return up.length ? up.join(" ") : "none";
        }
    }

    // Keep Awake, so it can be bound to a key and driven from a test. The
    // inhibitor itself is held by the bar window; this is the flag it reads.
    IpcHandler {
        target: "idle"

        function hold(state: string): string {
            if (state === "toggle")
                Idle.toggle();
            else if (state === "on" || state === "off")
                Idle.hold = state === "on";
            else if (state !== "")
                return "hold takes on, off or toggle";
            return Idle.hold ? "HOLD" : "AUTO";
        }

        function state(): string {
            return Idle.hold ? "HOLD" : "AUTO";
        }
    }

    IpcHandler {
        target: "messages"

        function state(): string {
            return `${Messages.state} running=${Messages.running} unread=${Messages.unread} tray=${Messages.item?.id ?? "-"}`;
        }

        function tray(): string {
            const items = SystemTray.items?.values ?? [];
            if (!items.length)
                return "no tray items";
            return items.map(i => `${i.id} | icon=${i.icon} | status=${i.status} | tip=${i.tooltipTitle}`).join("\n");
        }
    }

    // Not scaffolding: `available` is the answer to "why does the panel say
    // nothing", and it cannot be read off the screen.
    IpcHandler {
        target: "vuln"

        function state(): string {
            return `available=${Vuln.available} scanning=${Vuln.scanning} synced=${Vuln.synced} count=${Vuln.count} high=${Vuln.high} upgrading=${Vuln.upgrading}`;
        }

        function sweep(): string {
            Vuln.refresh();
            return Vuln.scanning ? "scanning" : "refused";
        }
    }

    IpcHandler {
        target: "net"

        function state(): string {
            return `radio=${Wifi.radioOn} connected=${Wifi.connected} ssid=${Wifi.activeSsid} strength=${Wifi.strength} wired=${Wifi.wired}`;
        }

        // **The labels, which is what the dropdown actually draws.** It is the
        // only way to check demo mode's masking without reading it off the
        // screen, and it is the right thing to print either way: `state`
        // above answers "what am I on", this answers "what is on the panel".
        // The list is only populated while the dropdown is open.
        function networks(): string {
            if (!Wifi.networks.length)
                return "none scanned; the list only fills while the dropdown is open";
            return Wifi.networks.map(n => `${n.label}${n.connected ? " *" : ""}`).join("\n");
        }
    }

    IpcHandler {
        target: "lock"

        // Locking and querying are safe to expose; **there is deliberately no
        // `unlock`.** An IPC unlock would release the session lock without any
        // authentication -- any local process could run `ipc call lock unlock`
        // and walk past the lockscreen. The only way out is a correct PAM
        // submit; a lock that genuinely wedges after a *successful* auth is
        // released by the guarded retry timer in LockScreen, and a truly stuck
        // lock is a TTY's job (see the Security section), not an open door.
        function lock(): void {
            ShellState.locked = true;
        }
        function isLocked(): bool {
            return ShellState.locked;
        }
    }

    IpcHandler {
        target: "profile"

        // Apply a profile by name, case-insensitive. Returns what it did so the
        // wrayth-profile script can report failure.
        function set(name: string): string {
            return Theme.apply(name) ? `APPLIED ${Theme.activeProfile}` : `UNKNOWN PROFILE ${name}`;
        }
        function get(): string {
            return Theme.activeProfile;
        }
        function list(): string {
            return Profiles.names.join("\n");
        }
        function preview(name: string): string {
            return Theme.preview(name) ? `PREVIEW ${Theme.profile}` : `UNKNOWN PROFILE ${name}`;
        }
        function clearPreview(): void {
            Theme.clearPreview();
        }
    }
}
