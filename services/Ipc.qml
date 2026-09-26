import Quickshell
import Quickshell.Hyprland
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
            if (["grid", "editor", "pools", "effects", "privacy", "system"].indexOf(name) < 0)
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
    readonly property var dropdownNames: ["ident", "wifi", "bluetooth", "power", "audio", "tray", "comms", "calendar", "input"]

    // The screen a dropdown opened without a click belongs on.
    function focusedScreen(): string {
        return ShellState.focusedScreen;
    }

    function readoutX(name: string, screen: string): string {
        const x = ShellState.anchorFor(name, screen);
        return x < 0 ? "none" : String(Math.round(x));
    }

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
            // On the focused screen, under the readout that owns it there, so
            // the panel hangs where a click would have put it.
            ShellState.openDropdown(name, root.focusedScreen());
            return name;
        }
        function close(): void {
            ShellState.closeDropdown("ipc: dropdown close");
        }
        // Where a readout sits on the bar, in bar-window x, or `none` when it
        // has not published one (it is hidden). For the tests' pointer.
        function anchor(name: string): string {
            return root.readoutX(name, root.focusedScreen());
        }
        // The same, on a named screen (`hyprctl monitors` names).
        function anchorOn(name: string, screen: string): string {
            return root.readoutX(name, screen);
        }
        function screen(): string {
            return ShellState.dropdown ? ShellState.dropdownScreen : "none";
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

        // The monitor showing the deck, or "none".
        function screen(): string {
            return Deck.monitorName || "none";
        }
    }

    // Audio: Super + Shift + A, and what the tests read.
    IpcHandler {
        target: "audio"

        function next(): string {
            return Audio.cycleOutput();
        }
        function output(): string {
            return Audio.sink ? `${Audio.sink.name} ${Math.round(Audio.volume * 100)}${Audio.muted ? " muted" : ""}` : "none";
        }
        function input(): string {
            return Audio.source ? `${Audio.source.name}${Audio.micMuted ? " muted" : ""}` : "none";
        }
        function apps(): string {
            return Audio.streams.map(n => Audio.appName(n)).join(",") || "none";
        }
        function volume(value: string): string {
            Audio.setVolume(Audio.sink, Number(value));
            return `${Audio.snap(Number(value))}`;
        }
        function outputs(): string {
            return Audio.outputs.map(n => Audio.shortName(n)).join(",") || "none";
        }
    }

    // Super + /, and what the tests read and do.
    IpcHandler {
        target: "keybinds"

        function toggle(): void {
            ShellState.openExclusive(ShellState.keybindsOpen ? "" : "keybinds");
        }
        function open(): void {
            ShellState.openExclusive("keybinds");
        }
        function close(): void {
            ShellState.keybindsOpen = false;
        }
        // "<id>=<keys>" for Wrayth's binds, changed ones marked with a *.
        function list(): string {
            return Keybinds.binds.filter(b => b.ours).map(b => `${b.id}=${b.keys}${b.changed ? "*" : ""}`).join(";") || "none";
        }
        function theirs(): string {
            return `${Keybinds.binds.filter(b => !b.ours && !b.fixed).length}`;
        }
        // The labels the list gives the user's own binds (their descriptions).
        function theirLabels(): string {
            return Keybinds.binds.filter(b => !b.ours && !b.fixed).map(b => b.label).join(";") || "none";
        }
        function refresh(): void {
            Keybinds.refresh();
        }
        function capture(id: string): void {
            ShellState.keybindCapture(id);
        }
        // "swap", "theirs", "strand" or "none": the question a capture asked.
        function pending(): string {
            return ShellState.keybindPending || "none";
        }
        function confirm(): void {
            ShellState.keybindAnswer(true);
        }
        function cancel(): void {
            ShellState.keybindAnswer(false);
        }
        function reset(id: string): void {
            Keybinds.reset(id);
        }
        function capturing(): bool {
            return Keybinds.capturing;
        }
    }

    // COMMS, for the tests.
    IpcHandler {
        target: "comms"

        function state(): string {
            return `history=${Notifications.history.length} unseen=${Notifications.unseen} dnd=${Notifications.dnd} fullscreen=${Notifications.fullscreen} cards=${Notifications.list.length}`;
        }
        function dnd(on: string): string {
            Notifications.dnd = on === "on";
            return `${Notifications.dnd}`;
        }
        function apps(): string {
            return Notifications.groups.map(g => `${g.app}:${g.entries.length}`).join(",") || "none";
        }
    }

    IpcHandler {
        target: "tray"

        function items(): string {
            return Tray.items.map(i => Tray.nameOf(i)).join(",") || "none";
        }
    }

    IpcHandler {
        target: "polkit"

        // Whether the agent is registered and a request is up. Nothing more:
        // there is no way to answer a request from here.
        function state(): string {
            return `enabled=${Polkit.enabled} registered=${Polkit.registered} active=${Polkit.active} screen=${Polkit.active ? Polkit.screen : "none"} submitted=${Polkit.previewSubmitted}`;
        }
        // The prompt with a stand-in request that is not connected to polkit
        // and cannot authorise anything: for testing how it is drawn.
        function preview(): void {
            Polkit.startPreview();
        }
        // Closes that stand-in, as its CANCEL does.
        function endPreview(): void {
            Polkit.previewSubmitted = -1;
            Polkit.previewing = false;
        }
    }

    // Super + Shift + V, and what the tests read.
    IpcHandler {
        target: "clipboard"

        function toggle(): void {
            ShellState.openExclusive(ShellState.clipboardOpen ? "" : "clipboard");
        }
        function open(): void {
            ShellState.openExclusive("clipboard");
        }
        function close(): void {
            ShellState.clipboardOpen = false;
        }
        // The entries, newest first: kind and a short preview (text only).
        function list(): string {
            return Clipboard.ordered.map(e => `${e.kind}${e.pinned ? "*" : ""}:${e.kind === "text" ? e.preview.slice(0, 24) : e.bytes}`).join("|") || "none";
        }
        function skipped(): string {
            return Clipboard.lastSkip || "none";
        }
        function mode(): string {
            return `${Clipboard.history} ${Clipboard.onLock}`;
        }
        function setHistory(which: string): string {
            Clipboard.setHistory(which);
            return Clipboard.history;
        }
        function setOnLock(which: string): string {
            Clipboard.setOnLock(which);
            return Clipboard.onLock;
        }
        // Removes the entry at a position in `list` (1 = the first shown).
        function remove(position: int): string {
            const e = Clipboard.ordered[position - 1];
            if (!e)
                return "none";
            Clipboard.remove(e.key);
            return `${e.kind}`;
        }
        function pinFirst(): string {
            const e = Clipboard.ordered.find(x => !x.pinned);
            if (e)
                Clipboard.togglePin(e.key);
            return e ? `${e.key}` : "none";
        }
    }

    // Print, Alt + Print, Shift + Print.
    IpcHandler {
        target: "screenshot"

        function region(): string {
            return Screenshot.start("region");
        }
        function window(): string {
            return Screenshot.start("window");
        }
        function screen(): string {
            return Screenshot.start("screen");
        }
        // For the tests: the selector's mode, and choosing a region without a
        // pointer (x y w h in the focused screen's own coordinates).
        function mode(which: string): string {
            if (Screenshot.modes.indexOf(which) < 0)
                return "one of region, window, screen";
            Screenshot.mode = which;
            return which;
        }
        function last(): string {
            return Screenshot.last || "none";
        }
        function geometry(): string {
            return Screenshot.lastGeometry || "none";
        }
        // What DELETE does, for the tests: only a file in the screenshots
        // folder, like the button.
        function remove(file: string): string {
            Screenshot.remove(file);
            return Screenshot.ours(file) ? "removing" : "refused";
        }
    }

    // The media keys, and the SIGNAL panel's sources.
    IpcHandler {
        target: "media"

        function toggle(): string {
            return Media.toggle();
        }
        function next(): string {
            return Media.next();
        }
        function previous(): string {
            return Media.previous();
        }
        function sources(): string {
            return Media.sources.map(src => `${src.kind}:${src.app}`).join(",") || "none";
        }
        function current(): string {
            return Media.current ? `${Media.current.kind}:${Media.current.app} cava=${Media.cavaSource}` : "none";
        }
        function select(app: string): string {
            const src = Media.sources.find(x => x.app.toLowerCase() === app.toLowerCase());
            if (!src)
                return "none";
            Media.select(src.key);
            return src.key;
        }
    }

    // The volume and brightness popup, for the tests: there is no audio server
    // or backlight in a nested session to change.
    IpcHandler {
        target: "osd"

        function flash(which: string): string {
            const kinds = { vol: "volume", bri: "brightness", media: "media" };
            if (!kinds[which])
                return "one of vol, bri, media";
            Osd.flash(kinds[which]);
            return which;
        }
        function state(): string {
            return Osd.showing || "none";
        }
        // The screen it shows on (the focused one).
        function screen(): string {
            return ShellState.focusedScreen || "none";
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
        // Forgets the COMMS history (what CLEAR ALL does).
        function clear(): string {
            const n = Notifications.history.length;
            Notifications.clearHistory();
            return `${n} cleared`;
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
            for (const name of ["capture", "keybinds", "clipboard"])
                if (ShellState[`${name}Open`])
                    was.push(name);
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

        // The screen the open full-screen overlay is on, or "none".
        function screen(): string {
            return ShellState.anyOverlay ? ShellState.overlayScreen : "none";
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
            for (const name of ["capture", "keybinds", "clipboard"])
                if (ShellState[`${name}Open`])
                    up.push(name);
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
        // Which screens have a lock surface, space-separated: every screen
        // must be covered. Names only -- nothing about what is typed.
        function surfaces(): string {
            return Lock.surfaceScreens.slice().sort().join(" ") || "none";
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

    // Keyboard layouts and input methods. `next` is Super + Space. `simulate`
    // shows made-up modes instead of the real ones ("EN:ENGLISH (US),あ:JAPANESE
    // // HIRAGANA"), for testing the readout without touching the keyboard;
    // `simulate ""` ends it.
    IpcHandler {
        target: "input"

        function next(): void {
            InputModes.next();
        }
        function state(): string {
            return JSON.stringify({ shown: InputModes.shown, current: InputModes.current, simulating: InputModes.simulating, modes: InputModes.modes });
        }
        function simulate(spec: string): string {
            InputModes.simulatedIndex = 0;
            InputModes.simulated = spec === "" ? [] : spec.split(",").map((p, i) => {
                const [glyph, ...name] = p.split(":");
                return { id: `sim:${i}`, kind: "layout", name: name.join(":") || glyph, code: glyph, glyph: glyph };
            });
            return `${InputModes.simulated.length} simulated`;
        }
    }

    // NIGHT LIGHT, for tests and scripts: the settings as the dropdown sets them.
    IpcHandler {
        target: "nightlight"

        function state(): string {
            return JSON.stringify({ on: NightLight.on, active: NightLight.active, kelvin: NightLight.kelvin, schedule: NightLight.schedule, from: NightLight.from, to: NightLight.to, available: NightLight.available });
        }
        function toggle(): void {
            NightLight.setOn(!NightLight.on);
        }
        function schedule(which: string): string {
            NightLight.setSchedule(which);
            return NightLight.schedule;
        }
        function times(from: string, to: string): string {
            return NightLight.setTimes(from, to) ? "ok" : "invalid";
        }
    }

    // Airplane mode and VPNs. `simulate true` swaps in made-up state for tests,
    // so toggles never touch a radio or a tunnel; `simulate false` ends it.
    IpcHandler {
        target: "radio"

        function state(): string {
            return JSON.stringify({ airplane: Radio.airplane, tunnelUp: Radio.tunnelUp, simulating: Radio.simulating, vpns: Radio.vpns });
        }
        function simulate(on: bool): string {
            Radio.simulate(on);
            return Radio.simulating ? "simulating" : "real";
        }
        function airplane(on: bool): string {
            if (!Radio.simulating)
                return "only while simulating";
            Radio.setAirplane(on);
            return "ok";
        }
        function vpn(name: string, up: bool): string {
            if (!Radio.simulating)
                return "only while simulating";
            Radio.setVpn(name, up);
            return "ok";
        }
    }

    // OVERVIEW, Super + Tab.
    IpcHandler {
        target: "overview"

        function toggle(): void {
            ShellState.openExclusive(ShellState.overviewOpen ? "" : "overview");
        }
        function open(): void {
            ShellState.openExclusive("overview");
        }
        function close(): void {
            ShellState.overviewOpen = false;
        }
    }

    // The window switcher, Alt + Tab / Alt + Shift + Tab. `commit` focuses
    // the selection, as letting go of Alt does.
    IpcHandler {
        target: "switcher"

        function next(): void {
            Switcher.next();
        }
        function prev(): void {
            Switcher.prev();
        }
        function commit(): void {
            Switcher.commit();
        }
        function close(): void {
            ShellState.switcherOpen = false;
        }
    }
}
