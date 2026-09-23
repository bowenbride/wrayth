# wrayth header strip.
#
# Left: the slanted accent TTY.nn tab, nn being the real /dev/pts number.
# Middle: "bash // <cwd>" in dim. Right: the katakana 接続中 in signal.
#
# Colours are read from kitty's palette slots, which wrayth-profile
# regenerates per profile, so this file never needs to know the palette.
#
# The line at the foot of the strip is a per-cell underline: accent under the
# red block, hair under the title and the katakana, separating the strip from
# the terminal text below it.
# It cannot come from kitty's tab bar margin: that is one rect in one colour
# for the whole strip, and it also paints the leftover pixels at each end of
# the cell grid, which have to stay invisible.

import math
import os

from kitty.boss import get_boss
from kitty.fast_data_types import (
    cell_size_for_window,
    current_os_window,
    get_options,
    wcswidth,
)
from kitty.tab_bar import DrawData, ExtraData, TabBarData, as_rgb
from kitty.utils import color_as_int

SLANT = "\ue0b0"
KATAKANA = "接続中"

# Hyprland cuts 16 px off each window corner (decoration:rounding 34, which is
# what a 16 px leg costs). The strip runs edge to edge and lets the corner clip
# it -- the block starts at x = 0 so its top-left is cut diagonally and it sits
# flush against the border. What the cut must not eat is the *text*, so the
# padding inside the block, and the padding after the katakana, are sized from
# this.
CHAMFER_PX = 16


def _slot(name: str) -> int:
    return as_rgb(color_as_int(getattr(get_options(), name)))


def _edge_cells() -> int:
    """How many cells the window chamfer covers along the top edge.

    Measured rather than assumed: the cell width moves with the font size, so a
    hard-coded column count would stop clearing the corner the moment the font
    changed. This is padding *inside* the strip, not an offset of it -- the
    strip itself always starts at x = 0.
    """
    try:
        width, _ = cell_size_for_window(current_os_window())
        if width > 0:
            return max(1, math.ceil(CHAMFER_PX / width))
    except Exception:
        pass
    # JetBrains Mono at 11pt is about 9 px wide, so two cells clears 16.
    return 2


def _cwd() -> str:
    """The active window's working directory, as ~/... where possible."""
    try:
        w = get_boss().active_window
        path = w.cwd_of_child or ""
    except Exception:
        path = ""
    if not path:
        return ""
    home = os.path.expanduser("~")
    if path == home:
        return "~"
    if path.startswith(home + os.sep):
        return "~" + path[len(home):]
    return path


def _tty_number(tab: TabBarData, fallback: int) -> str:
    """The N from /dev/pts/N of this tab's active window, zero-padded.

    What `tty` prints inside that window, so the strip names the real device
    rather than counting tabs. The shell's stdin is the pts, so the slave path
    is read straight off it; kitty exposes the master fd, not the slave name.

    Numbers are reused as terminals close, which is the kernel's behaviour and
    is left alone -- the number names the device, it is not an identifier for
    the window.
    """
    try:
        for t in get_boss().all_tabs:
            if t.id != tab.tab_id:
                continue
            window = t.active_window
            pid = window.child.pid if window is not None else None
            if not pid:
                break
            device = os.readlink(f"/proc/{pid}/fd/0")
            if device.startswith("/dev/pts/"):
                return f"{int(device.rsplit('/', 1)[1]):02d}"
            break
    except Exception:
        pass
    # A window with no pts of its own -- never seen in practice, but the strip
    # has to draw something.
    return f"{fallback:02d}"


def _underline(screen, colour: int) -> None:
    """Draw the strip's bottom line under the cells drawn after this call.

    The line is a per-cell underline rather than the tab bar's bottom margin,
    which is one rect in one colour across the whole strip. Per cell, the run
    under the red block can carry the line while the rest carries none.

    `modify_font underline_position` puts it on the cell's last pixel row, so
    it sits at the foot of the strip rather than through it.
    """
    screen.cursor.decoration = 1
    screen.cursor.decoration_fg = colour


def _put(screen, text: str, fg: int, bg: int, bold: bool = False) -> None:
    screen.cursor.fg = fg
    screen.cursor.bg = bg
    screen.cursor.bold = bold
    screen.draw(text)


def draw_tab(
    draw_data: DrawData,
    screen,
    tab: TabBarData,
    before: int,
    max_title_length: int,
    index: int,
    is_last: bool,
    extra_data: ExtraData,
) -> int:
    ground = _slot("background")
    accent = _slot("color1")
    signal = _slot("color6")
    dim = _slot("color8")
    hair = _slot("inactive_border_color")

    # --- the tab itself ---------------------------------------------------
    # The block starts at column 0 and is flush against the border; the window's
    # own chamfer cuts its top-left corner. Only the text is kept clear of the
    # cut, by padding inside the block.
    pad = " " * _edge_cells()

    tty = _tty_number(tab, index)
    if tab.is_active:
        # Accent under the solid block, hair from the slant onwards: the line
        # separates the strip from the terminal text below it, and changes
        # colour exactly where the block ends.
        _underline(screen, accent)
        _put(screen, f"{pad}TTY.{tty} ", ground, accent, bold=True)
        _underline(screen, hair)
        # The trailing slant: accent foreground on the strip's own background.
        _put(screen, SLANT, accent, ground)
    else:
        _underline(screen, hair)
        _put(screen, f"{pad}TTY.{tty} ", dim, ground)

    if not is_last:
        return screen.cursor.x

    # --- everything after the last tab ------------------------------------
    cwd = _cwd()
    middle = f" bash // {cwd}" if cwd else " bash"
    _put(screen, middle, dim, ground)

    # The katakana is pushed hard right. Its cell width is not its character
    # count -- these are double-width -- so the gap is measured with wcswidth.
    # The katakana stops clear of the top-right chamfer, with the same margin
    # the block keeps from the top-left one.
    trailing = KATAKANA + " " * (_edge_cells() + 1)
    pad = screen.columns - screen.cursor.x - wcswidth(trailing)
    if pad > 0:
        _put(screen, " " * pad, dim, ground)
    _put(screen, trailing, signal, ground)

    return screen.cursor.x
