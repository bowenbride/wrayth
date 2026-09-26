# Wrayth — design notes for contributors

How Wrayth looks, why, and where things live. Read this before changing a
panel: most of the rules below were learned by getting them wrong first.

## Principles

- **70 / 20 / 10.** 70% neutral base, 20% `signal` (data), 10% `accent`. The
  accent only marks what is active, hot, selected, or needs attention.
- **No rounded corners.** Panels are chamfered: cut top-right and bottom-left
  (16 px; 18 px on the HUD). The deck is the exception — its panels meet each
  other, so each cuts the corners that make the meeting point read as a
  junction. Windows get Hyprland's rounding at `rounding_power = 1`, which
  turns the rounding into a straight 16 px cut to match.
- **Hairline borders:** a 1 px frame in `hair` around an inner fill.
- **Translucent panels:** `panel` / `panel2` fills with Hyprland's blur behind,
  confined to the drawn shape (`ignore_alpha`), so chamfers stay crisp.
- **Labels over decoration:** small, uppercase, tracked labels —
  `HOST <name> // UPLINK <ssid>`. The separator is ` // `, and only between a
  label and its value. Small katakana tags sit beside headers in `signal`, at
  their own size, **centred vertically on the title's ink**: use
  `components/KanaTag.qml` and give it the title, never a hand-tuned offset.
- **Data stays data.** The SIGNAL spectrum is `signal` at every level; a high
  reading is not a reason to use the accent.
- **No glow anywhere.** Accent is drawn plain; a halo cost more legibility than
  it bought.
- **Optical centring, always.** Text and icons are centred on their *ink*, not
  their layout box. `components/Glyph.qml` centres on the tight bounding rect
  and is the reference; `NrLabel` has a `centred` mode. Check by measuring
  pixels, not by eye.
- **No interaction changes a layout.** Every element reserves the size of its
  widest state (working, success and failure labels included); varying text
  sits in a fixed slot.
- **No wrapping.** Single-line elements truncate with an ellipsis.

## Motion

One animation scale for the whole shell, in `config/Appearance.qml`:

| Duration | ms | Used for |
|---|---|---|
| `state` | 120 | press flashes, toggles, hovers — anything acknowledging input |
| `move` | 180 | something travelling from one place to another |
| `panel` | 250 | a panel, overlay or section appearing or leaving |
| `wallpaper` | 800 | wallpaper cross-fades |

Entry eases `OutCubic`, exit `InCubic`. Two deliberate exceptions: meters
settle over 900 ms (data settling, not an element arriving), and the deck uses
400 ms to match Hyprland's special-workspace animation. Layer surfaces are
faded by Hyprland (`hypr-wrayth.lua`), never by QML, or the fade doubles.

## Interaction states

One shared set for every clickable (`components/ActionState.qml`,
`Feedback.qml`, `WorkSegments.qml`):

- **Pressed:** a 35% accent flash over ~120 ms on *press*; the action runs one
  frame later so the acknowledgement always paints first.
- **Working:** the label becomes the verb (`LINKING`, `APPLYING`, `VERIFYING`),
  a four-segment block cycles, a 2 px accent line sweeps the bottom edge, and
  the element is disabled.
- **Success:** a brief `signal` flash, then the new state is the feedback.
- **Failure:** a glitch jolt, an accent border and `FAILED // <reason>` for
  ~3 s; a system error message also goes out as a notification.
- **Timeout:** anything working for 20 s fails as `TIMEOUT`.

**Text entry.** Slot fields (the lockscreen and Wi-Fi passphrases, the ID
block editor) show progress only by their boxes filling in the accent — no
caret, no focus frame. Free-text fields (`components/InputField.qml`) keep a
1 px accent caret.

**Bottom-edge buttons.** A button along a popup's bottom edge (`MIXER`,
`OPEN COMMS WORKSPACE`, `OPEN KEYBINDS FILE`) takes the panel's bottom-left
cut. **Full-screen views** (the picker's pages, the keybind list) have `BACK`
above the header, doing what Escape does.

**Reduced motion** (the SYSTEM page): `Appear` fades in over the `state`
duration with no rise, and glitches are off. **Game mode** pauses the
visualiser, glitches and the scanline band while anything is fullscreen
(`SystemSettings.gaming`); anything new that animates in the background should
check it too.

**Low-rate previews.** The overview and the window switcher use
`ScreencopyView` with `live: false` and capture a frame on a timer (one a
second in the overview, one on open in the switcher), inside a `Loader` that is
only active while the surface is shown, so closing it ends every capture.

**Privacy chips** sit at the ticker's left edge and take their width from the
ticker only; on a narrow bar they are clipped, never drawn over a readout.
Their sources are event-driven (PipeWire nodes, inotify on `/dev/video*`);
REC's clock ticks only while recording. Anything that reports a device in use
belongs here, in the alert colour; the accent is for the shell's own REC.

**Video wallpapers** play only on the desktop background, and only while
nothing covers them, nothing is fullscreen and the machine is on AC; every
other surface shows the video's first frame (made once with ffmpeg into
`~/.cache/wrayth/stills`).

**Icons.** New small icons come from **Material Symbols, Sharp style**
(square corners, no rounded ends or indents), never hand-drawn. They are
bundled as SVGs in `assets/icons/material-symbols-sharp/` with the set's
Apache 2.0 `LICENSE`, their path data listed in `config/Icons.qml`, and drawn
by `components/Icon.qml` in a profile token -- never the file's own colour.
In use: the tray (`inbox`), media controls (`skip_previous`, `play_arrow`,
`pause`, `skip_next`), the COMMS bell (`notifications`, `notifications_off`),
mute toggles (`volume_up`, `volume_off`, `mic`, `mic_off`) and chevrons
(`chevron_left`, `chevron_right`, `expand_more`). The bespoke bar marks stay
as they are: the Wi-Fi bars, the Bluetooth rune and the message bubble.

**Button hierarchy.**

- **Primary**: the one main action of a view -- accent frame, 12% accent
  tint, accent text. Rare: one per view at most (START RECORDING,
  AUTHENTICATE).
- **Secondary**: a hairline frame, text in the text colour (MIXER, CANCEL).
- **Quiet**: no frame, dim text, brightening on hover; for navigation and
  minor actions (CLEAR ALL, OPEN COMMS WORKSPACE ›, the COMMS bell).
- **BACK inside a dropdown is always quiet** (`components/QuietBack.qml`): a
  chevron and the name of where it returns to -- `‹ AUDIO`, `‹ TRAY`,
  `‹ UPLINK`, `‹ BLUETOOTH` -- with no frame and no chamfer. Full-screen
  views keep the framed BACK with its ESC keycap.

**The corner rule.** A chamfer appears only on an element sitting in a
chamfered corner of its container, echoing that corner: MIXER along the
audio dropdown's bottom edge, the leftmost Alt+Tab tile. Everything else is
square -- badges, chips, tiles, rows.

**App badges** (`components/AppBadge.qml`): two letters in Chakra Petch Bold
in a square with a hairline border, wherever an app needs a mark (tray,
window switcher, overview). The apps' own icons are not drawn: they bring
their own colours and render badly small.

**Key hints** are keycaps (`components/Keycap.qml`), named (`ENTER`, `ESC`),
in the surrounding text's colour.

## Building an interface: tokens and components

Every surface is assembled from shared pieces rather than styled by hand.

- **Tokens** (`config/Tokens.qml`) hold every colour (through the active
  profile), every type role (font, size, tracking), the spacing scale and
  common measures, the chamfer sizes, and the four durations with their two
  easing curves. A hex colour, pixel size or duration typed straight into a
  surface is a bug: add or reuse a token instead.
- **Components** (`components/ui/`, imported as `qs.components.ui`) are the
  building blocks, each defined once: `Label` and `Value` (a value that
  changes with the system is always a `Value`, never styled as a label),
  `Title` with its `JapaneseLabel`, `SectionLabel`, `EmptyState`, `Rule`,
  `BarDivider`, rows (`ListRow`, `BadgeRow`, `TwoLineRow`), `Button` in three
  kinds (primary, secondary, quiet), `BackControl`, `Chip`, `Toggle`,
  `SegmentMeter`, `VolumeLine`, `ConfirmInPlace`, `SlotInput`, `TextField`,
  `Keycap`, `Badge`, `Tag`, `IndicatorChip`, `StatusDot`, `WorkingIndicator`
  and `Scrollbar`. A new need gets a new component, not an inline restyle.
- **Surface templates.** Dropdowns share `DropdownFrame` (title and Japanese
  label, at most one header control, three standard widths); full-screen
  views, centred panels, notification cards and on-screen popups each follow
  one layout. A new surface picks the template that fits.
- **Icons** are glyphs from the bundled Material Symbols Sharp font, drawn by
  `components/Icon.qml` by name, snapped to whole pixels. Only four marks are
  drawn by hand: the Wi-Fi bars, the Bluetooth rune, the message bubble and
  the distro logo.
- **The `//` mark is rationed** to the ID block, the IDLE toggle, the
  DAEMONS // LOADED header and the lockscreen's operator line. Everywhere else,
  parallel items are separated by `·` and a label and its value by spacing and
  colour.
- **Check by measuring.** A change is finished when its widths, colours, type
  and alignment have been measured on screen against the tokens, not when it
  looks right.

## Colour

Every colour comes from the active profile's tokens (`config/Theme.qml`);
nothing is hard-coded.

| Token | Role |
|---|---|
| `ground`, `deep` | base and darkest background |
| `panelHex`, `panel`, `panel2`, `barBg` | solid and translucent fills |
| `hair`, `track`, `cell`, `mute` | borders, empty meter segments, subtle cells, inactive markers |
| `text`, `bright`, `dim` | body, titles and key values, labels |
| `signal` | data: graphs, readouts, katakana |
| `accent` | active, hot, selected |
| `alert` | warnings only |

### Profiles

Six presets share one layout (`config/Profiles.qml`):

| Profile | Accent / signal | Character |
|---|---|---|
| Circuit | red / teal | the balanced default |
| Sodium | streetlight yellow / cyan | loud and scrappy |
| Prism | magenta / cyan | the brightest |
| Redline | red / chrome | industrial |
| Oxide | amber / sea green | road-worn |
| Cobalt | blue / steel | cold and clean |

**Custom profiles** author nine colours — `GROUND`, `PANEL`, `HAIR`, `TEXT`,
`BRIGHT`, `DIM`, `SIGNAL`, `ACCENT`, `ALERT` — and derive the rest (`deep`,
`track`, `mute`, `cell`, `panel`, `panel2`, `barBg`) by the fixed ratios the
presets hold (see `config/Profiles.qml`). A custom profile's wallpaper is the
Circuit render recoloured: its red mapped to the profile's accent, its cyan to
its signal (`external/wrayth-wallpaper`, a colour lookup table — no network,
no generative model). Custom profiles behave like presets everywhere: kitty
colours, Hyprland borders, the deck's logo, the launcher.

`external/wrayth-profile` carries a second copy of the preset palette so it
works with the shell stopped; change both together.

## Structure

```
shell.qml            the root: one of each module per screen
config/              Theme (tokens), Appearance (sizes, fonts, durations),
                     Profiles, Paths, Customs, Machine
services/            singletons: system state and actions (Wifi, Audio, Media,
                     Tray, Lock, Polkit, Clipboard, Keybinds, Screenshot,
                     Planner, Vuln, Deck, Wallpapers, Effects, Ipc, ...)
components/          shared pieces: ChamferPanel, NrLabel, Glyph, Keycap,
                     KanaTag, VolumeControl, ActionButton, InputField,
                     PassphraseSlots, Wallpaper, ...
modules/             bar, deck (HUD, planner, signal, vuln), dropdowns,
                     launcher, lock, notifications, picker (with the effects
                     and privacy pages), popups, session, capture, polkit,
                     keybinds, clipboard, background, status
external/            what lives outside Quickshell: the Hyprland rules
                     (hypr-wrayth.lua) and complete config (hyprland.lua), the
                     wrayth-* helpers, kitty and fastfetch configs, the bash
                     integration (wrayth.bash), hypridle.conf
assets/              font, wallpapers, textures, the lockscreen's PAM stack
install.sh           the installer
```

**Surfaces.** Every per-screen surface takes its screens from
`ShellState.screens` (never `Quickshell.screens`), which leaves out the
temporary output the lockscreen uses to recover keyboard focus. Layer
namespaces are `wrayth-(bar|deck|deckbg|popup|overlay|notifications|background|scanlines|capture|polkit)`,
matched by exact string in `hypr-wrayth.lua` — change both together.

**Which screen.** Per-screen surfaces are one per screen, but most things
appear on one screen only, and each such thing names its screen:
`ShellState.dropdownScreen` (the bar that was clicked),
`ShellState.overlayScreen` (the screen focused when a full-screen overlay
opened), `Deck.monitorName` (the monitor showing `special:deck`) and
`ShellState.focusedScreen` (the popup, notifications, the screenshot selector
and the admin prompt's panel). The admin prompt is the one thing besides the
lockscreen that dims every screen; its keyboard grab is on the focused one
only. Anything a bar shows
about "the current workspace" comes from its own monitor
(`services/MonitorSpaces.qml`). Never drive a per-screen surface from one
global flag, or place it from the focused monitor's coordinates: that's how
dropdowns closed themselves and overlays grabbed the keyboard on every screen.
**The deck** is a Hyprland special workspace (`special:deck`) holding a kitty
window of class `wrayth-deck`, with the shell's panels drawn around it. The
shell sizes and places that window (`services/Deck.qml`,
`modules/deck/DeckOverlay.qml`), because a window rule cannot see the space the
bar reserves. Its width is a whole number of kitty cells, and the panels are
laid out from it. The layout targets 1920×1080 logical pixels and clips rather
than reflows below that.

**The deck terminal's greeting** comes from the bash integration
(`external/wrayth.bash`, loaded by one line in `~/.bashrc`): a fastfetch run
with a generated logo (`external/wrayth-emblem`: the distro's logo, recoloured
per character) and a welcome line. kitty's tab bar is drawn by
`external/tab_bar.py`; its header strip relies on `tab_bar_margin_color none`
so the partial cells at each end take the neighbouring cell's colour.

**Polling.** Readouts poll only while they are visible, except what the
always-visible bar ticker needs (firewall, packages, vulnerabilities, planner,
uplink). Nothing polls faster than it changes. Audio, media, the tray,
notifications and the clipboard are event-driven (PipeWire, MPRIS, D-Bus,
`wl-paste --watch`); only the SIGNAL panel's track position is re-read, once a
second, while the deck is open.

**Keybinds.** `hypr-wrayth.lua` binds from one catalogue, and every bind's
description is `wrayth:<id>:<group>:<label>:<default keys>`, which is how the
keybind list reads Hyprland's live binds. Add a bind to the catalogue, not as a
bare `hl.bind`, or the list cannot show it. A user's changes are applied by
`wrayth_apply_keybinds()` (unbind everything, then bind everything, so a swap
never leaves one action unbound) from `~/.config/wrayth/keybinds.lua`.

**Blur and opacity.** Never fade a subtree containing a blurred `Wallpaper`
through a parent's `opacity`: Qt's implicit opacity path composites the blur
to nothing. Enable `layer.enabled` on the fading parent instead.

## The lockscreen and its security

The lock uses Wayland's `ext-session-lock` through Quickshell and authenticates
with PAM against Wrayth's own stack (`assets/pam.d/passwd`: `pam_faillock`
around `pam_unix`), so nothing is installed under `/etc`.

- There is **no unauthenticated unlock**: no IPC, no logind hook. The only way
  out is a correct password.
- `lock.locked` is bound to a value that survives a hot reload
  (`PersistentProperties`), because a reloaded lock object would otherwise
  apply its default of "unlocked".
- If the lock client dies, the compositor keeps the session locked; the
  supervisor (`external/wrayth-shell`) starts a new shell, which takes the lock
  over (`misc:allow_session_lock_restore`). A take-over briefly sets
  `misc:lockdead_screen_delay` to 0 so Hyprland covers the screen until the new
  surface draws.
- After a switch to a text console, Hyprland does not return keyboard focus to
  a lock surface; `external/wrayth-lock-assist refocus` moves focus to a
  temporary output's lock surface and back to restore it.
- A faillock lockout is shown with its remaining time, read from the user's own
  tally; passwords typed during a timed lockout are not sent to PAM, since each
  wrong one would extend it.
- PAM runs in a forked child, so it can never block the interface; an attempt
  with no answer in 20 s is abandoned.

The threat model: the lock protects against someone at the keyboard and other
local users. It cannot protect against software already running as you.

**The admin prompt** (`services/Polkit.qml`) is Quickshell's polkit agent; the
password goes to polkit's setuid helper and nowhere else. Polkit allows one
agent per session and Wrayth never tries to displace another. Test sessions
set `WRAYTH_POLKIT=off`: a nested shell runs inside your real login session,
and must never become its agent. Test the prompt with `qs -c wrayth ipc call
polkit preview`, which is not connected to polkit and can authorise nothing.

**Privacy.** Notification history is memory only. Clipboard history is memory
only unless the user chooses `SAVE TO DISK` (an owner-only file, deleted when
they leave that mode), and `external/wrayth-clip` drops a copy marked
`x-kde-passwordManagerHint` before reading it. Keep all three true, and keep
the nested test's checks for them passing.

## Installing and updating

`install.sh` installs the configs a user may edit (`kitty.conf`,
`tab_bar.py`, `hypr-wrayth.lua`, `hypridle.conf`, the complete
`hyprland.lua`) as **copies**, never as links into the checkout, so an edit
never lands in Wrayth's own files. A re-run and `wrayth-update` (which runs
the new version's `install.sh --update-from <old commit>`) replace a copy only
while it is exactly what Wrayth shipped before; an edited one is kept, with
the new version saved beside it as `<file>.wrayth-new`. Updating never writes
to `~/.config/wrayth`, `~/.local/state/wrayth` or `~/.cache/wrayth`. When you
change a shipped config, bump `VERSION` in the release that carries it.

A user's own Hyprland settings belong in `~/.config/hypr/overrides.lua`,
which the complete setup's `hyprland.lua` loads last. Point people there rather
than at `hyprland.lua`: an edited `hyprland.lua` stops taking updates.

## Testing changes

- Hot reload: Quickshell reloads on file change; after editing, `touch
  shell.qml` if a change does not appear.
- IPC drives most surfaces for testing: `qs -c wrayth ipc show` lists targets.
- Verify a Hyprland config change with `hyprctl configerrors` in a running
  session — a config that parses can still fail at run time.
- For the lockscreen, test against a throwaway PAM stack in a copy of the
  shell, never your real one, and never test a reload without changing the
  file's contents (Quickshell skips unchanged files).
