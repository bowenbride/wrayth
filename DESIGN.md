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
  `HOST <name> // UPLINK <ssid>`. The separator is ` // `. Small katakana tags
  sit beside headers in `signal`.
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

**Key hints** are keycaps (`components/Keycap.qml`), named (`ENTER`, `ESC`),
in the surrounding text's colour.

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
services/            singletons: system state and actions (Wifi, Audio, Lock,
                     Planner, Vuln, Deck, Wallpapers, Effects, Ipc, ...)
components/          shared pieces: ChamferPanel, NrLabel, Glyph, Keycap,
                     ActionButton, InputField, PassphraseSlots, Wallpaper, ...
modules/             bar, deck (HUD, planner, signal, vuln), dropdowns,
                     launcher, lock, notifications, picker, popups, session,
                     background, status
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
namespaces are `wrayth-(bar|deck|deckbg|popup|overlay|notifications|background|scanlines)`,
matched by exact string in `hypr-wrayth.lua` — change both together.

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
uplink). Nothing polls faster than it changes.

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

## Testing changes

- Hot reload: Quickshell reloads on file change; after editing, `touch
  shell.qml` if a change does not appear.
- IPC drives most surfaces for testing: `qs -c wrayth ipc show` lists targets.
- Verify a Hyprland config change with `hyprctl configerrors` in a running
  session — a config that parses can still fail at run time.
- For the lockscreen, test against a throwaway PAM stack in a copy of the
  shell, never your real one, and never test a reload without changing the
  file's contents (Quickshell skips unchanged files).
