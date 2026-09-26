-- ~/.config/hypr/hyprland.lua -- wrayth's complete Hyprland setup.
--
-- Installed by wrayth's install.sh on a machine with no Hyprland config of its
-- own (or only Hyprland's generated default, or an old-style hyprland.conf).
-- Whatever was in ~/.config/hypr before was moved to a dated backup folder
-- beside it; the installer said where. This file is yours to edit: running the
-- installer again does not overwrite it.
--
-- It is a plain, working Hyprland config -- monitors, input, window
-- management keys -- and loads wrayth's own rules at the end (hypr-wrayth.lua,
-- beside this file). Everything it refers to is defined here or in that file;
-- it needs nothing else. Hyprland 0.56+ (the Lua config).
--
-- Keys that belong to wrayth (Super tap = launcher, Super + E = deck,
-- Super + P = power menu, Super + L = lock, Super + 1..0 = workspaces, and the
-- volume and brightness keys) are set in hypr-wrayth.lua. The ones below are
-- the everyday window keys and never touch those.

-- ===========================================================================
-- Monitors -- every connected display at its preferred mode, scale 1
-- ===========================================================================
-- wrayth is laid out for a screen at least 1920 x 1080 *logical* pixels. Scale
-- 1 keeps a 1080p screen at exactly that; Hyprland's "auto" can pick 1.25 or
-- more for a small 1080p laptop panel, which leaves the shell less room than
-- it needs (seen in testing: at an auto-chosen 2 it had half the space and its
-- bar overlapped itself). On a 4K screen, 2 gives 1920 x 1080 and suits it.
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = 1,
})

-- ===========================================================================
-- Programs
-- ===========================================================================
local terminal = "kitty"

hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

-- ===========================================================================
-- Look and layout
-- ===========================================================================
hl.config({
    general = {
        gaps_in     = 5,
        gaps_out    = 12,
        border_size = 1,
        col = {
            active_border   = "rgba(ffffff55)",
            inactive_border = "rgba(ffffff18)",
        },
        resize_on_border = true,
        allow_tearing    = false,
        layout           = "dwindle",
    },

    decoration = {
        active_opacity   = 1.0,
        inactive_opacity = 1.0,
        shadow = {
            enabled      = true,
            render_power = 4,
        },
    },

    animations = {
        enabled = true,
    },

    dwindle = {
        preserve_split = true,
    },

    misc = {
        -- wrayth draws the wallpaper; Hyprland's own would flash first.
        force_default_wallpaper = 0,
        disable_hyprland_logo   = true,
    },

    input = {
        kb_layout    = "us",
        follow_mouse = 1,
        sensitivity  = 0,
        touchpad = {
            natural_scroll = false,
        },
    },
})

-- Animation curves, all defined here.
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("almostLinear", { type = "bezier", points = { { 0.5, 0.5 }, { 0.75, 1 } } })
hl.curve("quick",        { type = "bezier", points = { { 0.15, 0 }, { 0.1, 1 } } })

hl.animation({ leaf = "global",        enabled = true, speed = 10,   bezier = "default" })
hl.animation({ leaf = "border",        enabled = true, speed = 5.39, bezier = "easeOutQuint" })
hl.animation({ leaf = "windows",       enabled = true, speed = 4.79, bezier = "easeOutQuint" })
hl.animation({ leaf = "windowsIn",     enabled = true, speed = 4.1,  bezier = "easeOutQuint", style = "popin 87%" })
hl.animation({ leaf = "windowsOut",    enabled = true, speed = 1.49, bezier = "almostLinear", style = "popin 87%" })
hl.animation({ leaf = "fadeIn",        enabled = true, speed = 1.73, bezier = "almostLinear" })
hl.animation({ leaf = "fadeOut",       enabled = true, speed = 1.46, bezier = "almostLinear" })
hl.animation({ leaf = "fade",          enabled = true, speed = 3.03, bezier = "quick" })
hl.animation({ leaf = "layers",        enabled = true, speed = 3.81, bezier = "easeOutQuint" })
hl.animation({ leaf = "workspaces",    enabled = true, speed = 1.94, bezier = "almostLinear", style = "fade" })

-- Touchpad: three-finger swipe between workspaces.
hl.gesture({
    fingers   = 3,
    direction = "horizontal",
    action    = "workspace",
})

-- ===========================================================================
-- Window keys (wrayth's own keys are in hypr-wrayth.lua)
-- ===========================================================================
local mod = "SUPER"

-- Each bind says what it is: the KEYBINDS overlay (Super + /) lists it under
-- its group, and can move it (your changes go to ~/.config/wrayth/keybinds.lua,
-- read by hypr-wrayth.lua after this file).
local function desc(id, group, label, keys)
    return { description = "wrayth:" .. id .. ":" .. group .. ":" .. label .. ":" .. keys }
end
-- The mouse binds: listed in KEYBINDS, but not moved from there.
local function fixed(group, label, opts)
    local o = opts or {}
    o.description = "wrayth-fixed:" .. group .. ":" .. label
    return o
end

hl.bind(mod .. " + Q",         hl.dsp.exec_cmd(terminal),                          desc("window-terminal", "WINDOWS", "Open a terminal", mod .. " + Q"))
hl.bind(mod .. " + C",         hl.dsp.window.close(),                              desc("window-close", "WINDOWS", "Close the window", mod .. " + C"))
hl.bind(mod .. " + V",         hl.dsp.window.float({ action = "toggle" }),         desc("window-float", "WINDOWS", "Float or tile the window", mod .. " + V"))
hl.bind(mod .. " + F",         hl.dsp.window.fullscreen(),                         desc("window-full", "WINDOWS", "Fullscreen", mod .. " + F"))
hl.bind(mod .. " + J",         hl.dsp.layout("togglesplit"),                       desc("window-split", "WINDOWS", "Toggle the split", mod .. " + J"))
hl.bind(mod .. " + SHIFT + M", hl.dsp.exit(),                                     desc("window-exit", "WINDOWS", "Exit Hyprland", mod .. " + SHIFT + M"))

hl.bind(mod .. " + left",  hl.dsp.focus({ direction = "left" }),  desc("focus-left", "WINDOWS", "Focus left", mod .. " + left"))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }), desc("focus-right", "WINDOWS", "Focus right", mod .. " + right"))
hl.bind(mod .. " + up",    hl.dsp.focus({ direction = "up" }),    desc("focus-up", "WINDOWS", "Focus up", mod .. " + up"))
hl.bind(mod .. " + down",  hl.dsp.focus({ direction = "down" }),  desc("focus-down", "WINDOWS", "Focus down", mod .. " + down"))

-- Super + Shift + number moves the focused window to that workspace.
-- (Super + number, going to it, is wrayth's: it closes the deck first.)
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }),
        desc("move-" .. i, "WORKSPACES", "Move the window to workspace " .. i, mod .. " + SHIFT + " .. key))
end

hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }), fixed("WORKSPACES", "Next workspace (scroll)"))
hl.bind(mod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }), fixed("WORKSPACES", "Previous workspace (scroll)"))
hl.bind(mod .. " + mouse:272",  hl.dsp.window.drag(),   fixed("WINDOWS", "Move a window (drag)", { mouse = true }))
hl.bind(mod .. " + mouse:273",  hl.dsp.window.resize(), fixed("WINDOWS", "Resize a window (drag)", { mouse = true }))

-- ===========================================================================
-- Window rules
-- ===========================================================================
hl.window_rule({
    name  = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

-- XWayland drag-and-drop helpers must not take focus.
hl.window_rule({
    name  = "fix-xwayland-drags",
    match = {
        class      = "^$",
        title      = "^$",
        xwayland   = true,
        float      = true,
        fullscreen = false,
        pin        = false,
    },
    no_focus = true,
})

-- ===========================================================================
-- wrayth -- after the above, so its keys and rules apply over it
-- ===========================================================================
require("hypr-wrayth")

-- ===========================================================================
-- Your own settings -- ~/.config/hypr/overrides.lua, if you make one
-- ===========================================================================
-- Loaded last, so anything in it applies over everything above: your own keys,
-- window rules, input settings, environment and start-up programs. Keep them
-- there rather than editing this file, and updates can go on replacing this
-- file with Wrayth's new version. A key of your own that is already bound
-- here needs `hl.unbind("KEYS")` first, or the key does both. To move one of
-- Wrayth's own keys, use the KEYBINDS list (Super + /) instead, and give your
-- binds a `description` so the list can name them.
local overrides = (os.getenv("XDG_CONFIG_HOME") or (os.getenv("HOME") .. "/.config")) .. "/hypr/overrides.lua"
local f = io.open(overrides)
if f then
    f:close()
    dofile(overrides)
end
