-- wrayth -- standalone Hyprland integration.
--
-- Everything Hyprland needs to run the wrayth shell: the layer and window
-- rules, the animation curve and decoration the shell was designed against,
-- the start-up hook, and a set of keybinds. **It depends on nothing defined
-- anywhere else** -- no curve, variable, colour, monitor name or script outside
-- this file and wrayth's own checkout -- so it loads on a bare Hyprland config
-- with zero errors (checked with `Hyprland --verify-config`).
--
-- install.sh places it at ~/.config/hypr/hypr-wrayth.lua and loads it for you
-- -- either inside the complete config it installs, or by adding one line,
-- `require("hypr-wrayth")`, to the end of your own hyprland.lua. Nothing needs
-- to be edited by hand. `./install.sh --uninstall` takes it out again.
--
-- It uses Hyprland's Lua config provider (the `hl` global, Hyprland 0.56+).
--
-- **Its keys replace any earlier bind on the same key.** Hyprland runs every
-- action bound to a key, so a key bound here and in your own config would do
-- both (Super + E opening a file manager *and* the deck). Each key below is
-- unbound first, so wrayth's action is the only one. Change the keys freely.

-- ===========================================================================
-- Layer rules -- the shell's surfaces
-- ===========================================================================

-- Every wrayth surface that comes and goes fades as one unit, blur included,
-- rather than sliding -- which is what stops blurred rectangles arriving from a
-- screen edge or lingering after their content is gone. QML never fades these
-- surfaces itself; that would double the fade.
hl.layer_rule({
    match     = { namespace = "wrayth-(bar|deck|deckbg|popup|overlay|notifications)" },
    animation = "fade",
})

-- Blur behind the translucent surfaces, confined to the shape actually drawn.
-- `ignore_alpha` leaves anything below the threshold unfrosted, so chamfered
-- corners, margins and the deck's terminal gap do not come out as hard-edged
-- frosted rectangles.
hl.layer_rule({
    match        = { namespace = "wrayth-(bar|deck|deckbg|popup|overlay|notifications)" },
    blur         = true,
    ignore_alpha = 0.15,
})

-- The screenshot selector disappears at once, never fading: it must be off
-- the screen before the capture is taken, and a fade would put it in the image.
hl.layer_rule({
    match   = { namespace = "wrayth-capture" },
    no_anim = true,
})

-- The admin prompt (polkit) and the dim it lays over every screen fade in and
-- out as one; the prompt itself is blurred behind like any panel.
hl.layer_rule({
    match     = { namespace = "wrayth-polkit" },
    animation = "fade",
})
hl.layer_rule({
    match        = { namespace = "wrayth-polkit" },
    blur         = true,
    ignore_alpha = 0.15,
})

-- The wallpaper layer is opaque and must not fade on a profile change (the
-- shell crossfades the image itself), so it is outside both rules above.
hl.layer_rule({
    match   = { namespace = "wrayth-background" },
    no_anim = true,
})

-- ===========================================================================
-- The deck -- a special workspace holding the wrayth-deck kitty window
-- ===========================================================================

-- The deck terminal floats on its own special workspace; the shell sizes and
-- moves it, because a window rule is evaluated in raw monitor coordinates and
-- cannot see the area the bar reserves.
-- `silent`, so the terminal opening at login does not bring the deck up with
-- it: the deck stays closed until Super + E.
--
-- `size` and `move` put it in its slot from the moment it opens -- the exact
-- slot on a 1920 x 1080 screen, a whole number of kitty cells wide. The shell
-- then places it precisely for whatever screen it is on (and again whenever
-- the layout changes), deck open or not; these only make sure it never
-- appears anywhere else first.
hl.window_rule({
    match     = { class = "wrayth-deck" },
    float     = true,
    workspace = "special:deck silent",
    size      = "1422 690",
    move      = "25 69",
})

-- kitty asks for activation when its screen is cleared; with focus-on-activate
-- on, that would pop the deck open on every profile change (which reprints the
-- greeting). Off, only Super + E opens it.
hl.window_rule({
    match             = { class = "wrayth-deck" },
    focus_on_activate = false,
})

-- The deck terminal's frame matches the panels beside it: a 1 px border, the
-- colour set per profile by ~/.local/bin/wrayth-profile.
hl.window_rule({
    match       = { class = "wrayth-deck" },
    border_size = 1,
})

-- No gaps or shadow around the deck terminal: the shell's layout is the layout.
hl.workspace_rule({
    workspace = "special:deck",
    gaps_out  = 0,
    gaps_in   = 0,
    no_shadow = true,
})

-- The deck's curve, defined here under wrayth's own name so it neither needs
-- nor disturbs a curve from any other config: fast out of the gate, settling
-- gently -- the same shape the deck was designed and measured against.
hl.curve("wraythDeck", { type = "bezier", points = { { 0.05, 0.7 }, { 0.1, 1 } } })

-- The deck fades as one thing. The panels are layer surfaces forced to `fade`
-- by the layer rule; the terminal is a window on the special workspace. Both
-- run at speed 4 (400 ms) on the same curve, so they arrive together rather
-- than in two pieces.
hl.animation({ leaf = "fadeLayersIn",  enabled = true, speed = 4, bezier = "wraythDeck" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 4, bezier = "wraythDeck" })
hl.animation({ leaf = "specialWorkspace", enabled = true, speed = 4, bezier = "wraythDeck", style = "fade" })

-- ===========================================================================
-- Decoration -- what the deck terminal needs to match the panels
-- ===========================================================================
-- These are global (they affect every window). rounding_power = 1 turns
-- Hyprland's rounded corners into straight cuts, and rounding = 34 makes the
-- cut's leg 16 px -- the same chamfer the shell's own panels cut -- so a window
-- corner and a panel corner beside it are the same shape. blur.special frosts
-- the whole background behind the deck (so the deck draws no backdrop of its
-- own), and dim_special darkens it. Adjust to taste, but the deck terminal
-- expects rounding_power = 1 and rounding = 34.
hl.config({
    decoration = {
        dim_special    = 0.38,
        -- The frosting every translucent panel was designed against: size 8,
        -- two passes (Hyprland's default is one, which reads as smeared rather
        -- than frosted behind the panels' fine type).
        blur           = {
            enabled        = true,
            special        = true,
            size           = 8,
            passes         = 2,
            ignore_opacity = true,
        },
        rounding       = 34,
        rounding_power = 1,
        -- A soft black shadow casts depth without tinting any profile.
        shadow = {
            color = "rgba(0000004D)",
            range = 15,
        },
    },
})

-- ===========================================================================
-- The lockscreen may be restarted into a held lock
-- ===========================================================================
-- If the lockscreen's process dies while the screen is locked, Hyprland keeps
-- the session locked and shows its own "lock screen app died" screen. This lets
-- a new wrayth lockscreen take that lock over (wrayth-shell starts one at once,
-- and wrayth-recover does it from a text console), so getting back in is typing
-- your password, not ending the session. It never unlocks anything: the new
-- lockscreen still needs your password. See SPEC.md, Security.
--
-- `session_lock_xray` keeps Hyprland drawing the desktop *behind* the lock
-- surface, which the lock surface covers opaquely until the password is
-- accepted; the unlock then dissolves onto the live desktop instead of onto
-- black. The surface is only ever transparent during that exit fade, after
-- authentication (see modules/lock/LockScreen.qml and SPEC.md, Security).
hl.config({
    misc = {
        allow_session_lock_restore = true,
        session_lock_xray          = true,
    },
})

-- ===========================================================================
-- Start-up -- launch the shell, the idle daemon, and the deck terminal
-- ===========================================================================
hl.on("hyprland.start", function()
    -- Through the supervisor, which starts `qs -c wrayth` and, if the shell
    -- ever dies while the screen is locked, starts it again straight into the
    -- lock (see external/wrayth-shell).
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/wrayth-shell")
    -- Idle: dim, lock, screen off, suspend (optional; needs the `hypridle`
    -- package and ~/.config/hypr/hypridle.conf -- see the install step).
    -- Once the SYSTEM page's idle timings have been set, the shell writes
    -- ~/.config/wrayth/hypridle.conf and hypridle runs from that instead.
    hl.exec_cmd('command -v hypridle > /dev/null || exit 0; f="$HOME/.config/wrayth/hypridle.conf"; [ -f "$f" ] && exec hypridle -c "$f"; exec hypridle')
    -- The deck terminal. The reset script is also how it is first started.
    hl.exec_cmd(os.getenv("HOME") .. "/.local/bin/wrayth-deck-reset")
end)

-- ===========================================================================
-- Keybinds
-- ===========================================================================
--
-- **One catalogue of every action Wrayth binds**, with an id, a group, a
-- plain label and its default keys. The KEYBINDS overlay (Super + /) lists
-- them from `hyprctl binds` -- the `wrayth:<id>:<label>` description is how it
-- tells Wrayth's binds from your own -- and moves them by writing
-- ~/.config/wrayth/keybinds.lua, a table of id = "NEW + KEYS" read here after
-- the defaults. Updates never touch that file, so your keys survive them.
--
-- Each key is unbound before it is bound (see the header): wrayth's action is
-- the only one on it.

local HOME = os.getenv("HOME")
local IPC = "qs -c wrayth ipc call "

local function goto_workspace(ws)
    -- Closes any open special workspace (the deck) first, so a number key
    -- means the same thing whether the deck is up or not. A function, so it
    -- reads the live state on each press.
    return function()
        local sp = hl.get_active_special_workspace()
        if sp then
            hl.dispatch(hl.dsp.workspace.toggle_special((sp.name:gsub("^special:", ""))))
        end
        hl.dispatch(hl.dsp.focus({ workspace = ws }))
    end
end

-- `own = false`: the action's default bind lives in Wrayth's complete
-- hyprland.lua (the window keys), so it is only re-bound here once moved.
local catalogue = {
    { id = "deck",          group = "SHELL", label = "Open or close the deck",        keys = "SUPER + E",         run = hl.dsp.workspace.toggle_special("deck") },
    { id = "deck-refresh",  group = "SHELL", label = "Refresh the deck terminal",     keys = "SUPER + SHIFT + E", run = hl.dsp.exec_cmd(HOME .. "/.local/bin/wrayth-deck-refresh") },
    { id = "launcher",      group = "SHELL", label = "Launcher",                      keys = "SUPER + SUPER_L",   run = hl.dsp.exec_cmd(IPC .. "launcher toggle"), opts = { release = true } },
    { id = "power",         group = "SHELL", label = "Power menu",                    keys = "SUPER + P",         run = hl.dsp.exec_cmd(IPC .. "power toggle") },
    { id = "lock",          group = "SHELL", label = "Lock the screen",               keys = "SUPER + L",         run = hl.dsp.exec_cmd(IPC .. "lock lock") },
    { id = "keybinds",      group = "SHELL", label = "Keybinds",                      keys = "SUPER + slash",     run = hl.dsp.exec_cmd(IPC .. "keybinds toggle") },
    { id = "clipboard",     group = "SHELL", label = "Clipboard history",             keys = "SUPER + SHIFT + V", run = hl.dsp.exec_cmd(IPC .. "clipboard toggle") },
    { id = "overview",      group = "SHELL", label = "Overview of the workspaces",    keys = "SUPER + Tab",       run = hl.dsp.exec_cmd(IPC .. "overview toggle") },
    { id = "switcher-next", group = "WINDOWS", label = "Switch windows (hold Alt)",     keys = "ALT + Tab",         run = hl.dsp.exec_cmd(IPC .. "switcher next") },
    { id = "switcher-prev", group = "WINDOWS", label = "Switch windows, backwards",     keys = "ALT + SHIFT + Tab", run = hl.dsp.exec_cmd(IPC .. "switcher prev") },
    { id = "record",        group = "MEDIA AND CAPTURE", label = "Record the screen, or stop", keys = "SUPER + SHIFT + R", run = hl.dsp.exec_cmd(IPC .. "record toggle") },
    { id = "input-next",    group = "SHELL", label = "Next keyboard layout or input method", keys = "SUPER + space", run = hl.dsp.exec_cmd(IPC .. "input next") },
    { id = "audio-next",    group = "MEDIA AND CAPTURE", label = "Next audio output", keys = "SUPER + SHIFT + A", run = hl.dsp.exec_cmd(IPC .. "audio next") },
    { id = "shot-region",   group = "MEDIA AND CAPTURE", label = "Screenshot of a region",          keys = "Print",         run = hl.dsp.exec_cmd(IPC .. "screenshot region") },
    { id = "shot-window",   group = "MEDIA AND CAPTURE", label = "Screenshot of the focused window", keys = "ALT + Print",   run = hl.dsp.exec_cmd(IPC .. "screenshot window") },
    { id = "shot-screen",   group = "MEDIA AND CAPTURE", label = "Screenshot of the whole screen",   keys = "SHIFT + Print", run = hl.dsp.exec_cmd(IPC .. "screenshot screen") },
    { id = "media-toggle",  group = "MEDIA AND CAPTURE", label = "Play or pause",     keys = "XF86AudioPlay",    run = hl.dsp.exec_cmd(IPC .. "media toggle"),   opts = { locked = true } },
    { id = "media-pause",   group = "MEDIA AND CAPTURE", label = "Pause",             keys = "XF86AudioPause",   run = hl.dsp.exec_cmd(IPC .. "media toggle"),   opts = { locked = true } },
    { id = "media-next",    group = "MEDIA AND CAPTURE", label = "Next track",        keys = "XF86AudioNext",    run = hl.dsp.exec_cmd(IPC .. "media next"),     opts = { locked = true } },
    { id = "media-prev",    group = "MEDIA AND CAPTURE", label = "Previous track",    keys = "XF86AudioPrev",    run = hl.dsp.exec_cmd(IPC .. "media previous"), opts = { locked = true } },
    -- Volume in 5% steps, so one press is one segment on the popup's
    -- 20-segment bar, capped at 100%. The popup follows PipeWire whoever
    -- moves it.
    { id = "volume-up",     group = "MEDIA AND CAPTURE", label = "Volume up",   keys = "XF86AudioRaiseVolume",
      run = hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), opts = { locked = true, repeating = true } },
    { id = "volume-down",   group = "MEDIA AND CAPTURE", label = "Volume down", keys = "XF86AudioLowerVolume",
      run = hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ 0; wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), opts = { locked = true, repeating = true } },
    { id = "volume-mute",   group = "MEDIA AND CAPTURE", label = "Mute",        keys = "XF86AudioMute", run = hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), opts = { locked = true } },
    -- Brightness straight to brightnessctl (an optional package).
    { id = "bright-up",     group = "MEDIA AND CAPTURE", label = "Brightness up",   keys = "XF86MonBrightnessUp",   run = hl.dsp.exec_cmd("brightnessctl set 5%+"), opts = { locked = true } },
    { id = "bright-down",   group = "MEDIA AND CAPTURE", label = "Brightness down", keys = "XF86MonBrightnessDown", run = hl.dsp.exec_cmd("brightnessctl set 5%-"), opts = { locked = true } },
    -- The window keys of Wrayth's complete hyprland.lua.
    { id = "window-terminal", group = "WINDOWS", label = "Open a terminal",          keys = "SUPER + Q",         run = hl.dsp.exec_cmd("kitty"), own = false },
    { id = "window-close",    group = "WINDOWS", label = "Close the window",         keys = "SUPER + C",         run = hl.dsp.window.close(), own = false },
    { id = "window-float",    group = "WINDOWS", label = "Float or tile the window", keys = "SUPER + V",         run = hl.dsp.window.float({ action = "toggle" }), own = false },
    { id = "window-full",     group = "WINDOWS", label = "Fullscreen",               keys = "SUPER + F",         run = hl.dsp.window.fullscreen(), own = false },
    { id = "window-split",    group = "WINDOWS", label = "Toggle the split",         keys = "SUPER + J",         run = hl.dsp.layout("togglesplit"), own = false },
    { id = "window-exit",     group = "WINDOWS", label = "Exit Hyprland",            keys = "SUPER + SHIFT + M", run = hl.dsp.exit(), own = false },
    { id = "focus-left",      group = "WINDOWS", label = "Focus left",               keys = "SUPER + left",      run = hl.dsp.focus({ direction = "left" }), own = false },
    { id = "focus-right",     group = "WINDOWS", label = "Focus right",              keys = "SUPER + right",     run = hl.dsp.focus({ direction = "right" }), own = false },
    { id = "focus-up",        group = "WINDOWS", label = "Focus up",                 keys = "SUPER + up",        run = hl.dsp.focus({ direction = "up" }), own = false },
    { id = "focus-down",      group = "WINDOWS", label = "Focus down",               keys = "SUPER + down",      run = hl.dsp.focus({ direction = "down" }), own = false },
}
for i = 1, 10 do
    local key = tostring(i % 10) -- 10 maps to key 0
    table.insert(catalogue, { id = "workspace-" .. i, group = "WORKSPACES", label = "Go to workspace " .. i,
        keys = "SUPER + " .. key, run = goto_workspace(tostring(i)) })
    table.insert(catalogue, { id = "move-" .. i, group = "WORKSPACES", label = "Move the window to workspace " .. i,
        keys = "SUPER + SHIFT + " .. key, run = hl.dsp.window.move({ workspace = i }), own = false })
end

-- The keys each action is bound to right now, so re-applying unbinds exactly
-- what it bound before.
local bound = {}

-- Applies the catalogue with your changes from ~/.config/wrayth/keybinds.lua.
-- Global, so the shell can call it through `hyprctl eval` the moment you
-- change a key, without reloading the whole config.
function wrayth_apply_keybinds()
    local ok, changes = pcall(dofile, HOME .. "/.config/wrayth/keybinds.lua")
    if not ok or type(changes) ~= "table" then
        changes = {}
    end
    -- Two passes, so a swap works: every key this bound before, and every key
    -- about to be used, is unbound first -- one action at a time, the second
    -- of two swapped actions would take the first's new bind away with its
    -- old one.
    local was = bound
    local plan = {}
    for _, a in ipairs(catalogue) do
        local keys = changes[a.id] or a.keys
        -- Wrayth's own binds always; a window key of the complete config only
        -- once it has been moved, or when it is coming back to its default.
        if a.own ~= false or keys ~= a.keys or was[a.id] then
            table.insert(plan, { a = a, keys = keys })
        end
    end
    for _, keys in pairs(was) do
        hl.unbind(keys)
    end
    for _, p in ipairs(plan) do
        if p.a.own == false and not was[p.a.id] then
            hl.unbind(p.a.keys) -- the complete config's own bind
        end
        if p.keys ~= "" then
            hl.unbind(p.keys)
        end
    end
    bound = {}
    for _, p in ipairs(plan) do
        local a, keys = p.a, p.keys
        -- id, group, label and default keys: what the KEYBINDS overlay
        -- lists, and what RESET goes back to.
        local opts = { description = "wrayth:" .. a.id .. ":" .. a.group .. ":" .. a.label .. ":" .. a.keys }
        for k, v in pairs(a.opts or {}) do
            opts[k] = v
        end
        if keys ~= "" then
            hl.bind(keys, a.run, opts)
            bound[a.id] = keys
        end
    end
end
wrayth_apply_keybinds()

-- While the KEYBINDS overlay captures a new combination, every bind is off, so
-- the keys reach the overlay instead of doing what they do. Escape is the one
-- way out of the submap, whatever happens to the shell.
hl.define_submap("wrayth-capture", function()
    hl.bind("Escape", hl.dsp.submap("reset"))
end)
