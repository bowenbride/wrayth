# wrayth.bash -- the wrayth shell's bash integration.
#
# Sourced from ~/.bashrc by one line install.sh adds (and --uninstall removes):
#
#     [ -r ~/.config/quickshell/wrayth/external/wrayth.bash ] && . ~/.config/quickshell/wrayth/external/wrayth.bash  # wrayth
#
# It gives every interactive bash the profile-coloured prompt, puts
# ~/.local/bin on PATH (where install.sh links the wrayth-* helpers), and in the
# deck terminal only (WRAYTH_DECK=1) prints the fetch and welcome greeting and
# defines `_wrayth_refresh`, which Super + Shift + E sends to redraw it. Nothing
# here runs outside an interactive shell. The design is described in DESIGN.md.

# Interactive shells only.
case $- in
    *i*) ;;
    *) return 0 2> /dev/null || exit 0 ;;
esac

# The helper scripts live here; without this wrayth-profile is not on PATH.
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Prompt: the ordinary [user@host dir]$ form, coloured per profile. The colour
# indices are kitty's palette slots, which wrayth-profile regenerates, so the
# prompt follows the active profile without bash knowing the palette.
#
# The sigil reports its own command's result. The live prompt's $ is the
# accent; once its command finishes, that *same* $ turns `signal` if it
# succeeded or accent if it failed. (The old rule coloured the *next* prompt
# after a failure, which reported the failure a line late.)
#
# A terminal cannot restyle a line it has already printed, and the result is
# not known until the command ends, so it is done in two passes -- and the
# second one only runs when the prompt is **provably** still where it was put.
# Everything here refuses rather than guesses: a colour that might be wrong is
# not worth having.
_wr_dim=90        # mute   -- brackets, @, and the "running" sigil
_wr_accent=31     # accent -- the username, and a command that failed
_wr_signal=36     # signal -- a command that succeeded
_wr_text=37       # text   -- the hostname
_wr_alert=33      # alert  -- the live prompt's sigil
_wr_bright=97     # bright -- the directory

_wr_row=          # screen row the live prompt was drawn on
_wr_col=          # column of its sigil, or empty when it cannot be known
_wr_after=        # cursor row immediately after the command was submitted
_wr_ran=0         # did a command actually run since the prompt was drawn
_wr_sigil='$'
[ "$(id -u)" -eq 0 ] && _wr_sigil='#'

# Settled once, here, rather than inside the helpers: **a command substitution
# runs in a subshell, and bash clears the interactive flag there**, so `$-`
# tested inside the helper says "not interactive" and every query was skipped.
case $- in
    *i*) _wr_live=1 ;;
    *) _wr_live=0 ;;
esac
# The two-pass sigil needs `${ ...; }`, which is bash 5.3. Without it the
# prompt still draws correctly; its sigil simply stays the accent.
if [ "${BASH_VERSINFO[0]}" -gt 5 ] 2> /dev/null \
    || { [ "${BASH_VERSINFO[0]}" -eq 5 ] && [ "${BASH_VERSINFO[1]}" -ge 3 ]; }; then
    _wr_twopass=1
else
    _wr_twopass=0
fi

# The cursor's current row, or nothing if it cannot be had safely.
_wr_cursor_row() {
    [ "$_wr_live" = 1 ] || return 1
    # **Not `-t 1`.** This is called through a function substitution, which
    # captures stdout, so stdout is a pipe here even in a terminal. The
    # terminal is reached explicitly through /dev/tty instead.
    [ -t 0 ] && [ -c /dev/tty ] || return 1
    # **Never ask while the user has typed ahead.** The answer would arrive
    # behind their keystrokes and reading it would swallow them.
    read -t 0 -N 0 2> /dev/null && return 1
    local reply='' ch row
    printf '\e[6n' > /dev/tty
    # **Byte at a time with `-N 1`, not `-d R`.** The reply has no newline in
    # it, and at this point the terminal is in canonical mode, so a delimited
    # read waits for a line that never comes and times out every prompt.
    # `read -N` is the form that takes the terminal out of canonical mode, so
    # each byte arrives as it is sent -- and no `stty` is needed, which is
    # what keeps a stray Ctrl+C from leaving the terminal raw.
    while IFS= read -rsN 1 -t 0.2 ch < /dev/tty 2> /dev/null; do
        [ "$ch" = R ] && break
        reply=$reply$ch
        [ ${#reply} -gt 12 ] && return 1
    done
    if [ "$ch" != R ]; then
        # **A late answer must not be left behind.** If the terminal did not
        # reply inside the timeout, its reply may still be on its way, and
        # anything left in the buffer is typed into the next command line --
        # observed as a stray `R` in front of it. Drain it and give up.
        while IFS= read -rsN 1 -t 0.05 ch < /dev/tty 2> /dev/null; do
            [ "$ch" = R ] && break
        done
        return 1
    fi
    reply=${reply##*[}
    row=${reply%%;*}
    [[ $row =~ ^[0-9]+$ ]] || return 1
    printf %s "$row"
}

# Repaint one prompt's sigil where it stands, and put the cursor back.
_wr_paint() {
    [ -n "$1" ] && [ -n "$_wr_col" ] || return 0
    printf '\e7\e[%d;%dH\e[%sm%s\e[0m\e8' "$1" "$_wr_col" "$2" "$_wr_sigil" > /dev/tty
}

# Is a row we recorded still the row it was? Proven, not assumed:
#   - the cursor has not moved above it (a `clear`, or a full-screen program
#     that homed the cursor, would put it above);
#   - and the screen cannot have scrolled -- either the cursor never reached
#     the last line, or it has not moved at all since the command started.
_wr_row_intact() {
    local row=$1 now=$2
    [ -n "$row" ] && [ -n "$now" ] || return 1
    [ "$now" -ge "$row" ] || return 1
    [ "$now" -lt "${LINES:-24}" ] || [ "$now" = "$_wr_after" ] || return 1
    return 0
}

# PS0, through a bash 5.3 function substitution so it runs in *this* shell and
# can remember what it saw. It prints nothing.
_wrayth_submit() {
    _wr_ran=1
    _wr_after=${ _wr_cursor_row; }
    # The prompt is only still where it was put if the cursor advanced past
    # it. A pasted command long enough to scroll the screen while it was being
    # typed would invalidate the row, so that case gives up instead.
    if [ -n "$_wr_after" ] && [ -n "$_wr_row" ] \
        && { [ "$_wr_after" -lt "${LINES:-24}" ] || [ "$_wr_after" = "$((_wr_row + 1))" ]; } \
        && [ "$_wr_after" -gt "$_wr_row" ]; then
        _wr_paint "$_wr_row" "$_wr_dim"
    else
        _wr_row=
    fi
}

_wrayth_prompt() {
    local status=$?
    local now=
    [ "$_wr_twopass" = 1 ] && now=${ _wr_cursor_row; }

    # 1. Settle the sigil of the prompt that has just finished.
    if [ "$_wr_ran" = 1 ]; then
        if _wr_row_intact "$_wr_row" "$now"; then
            if [ "$status" -eq 0 ]; then
                _wr_paint "$_wr_row" "$_wr_signal"
            else
                _wr_paint "$_wr_row" "$_wr_accent"
            fi
        fi
    elif [ -n "$now" ] && [ "$now" -gt 1 ]; then
        # Nothing ran: an empty Enter, or Ctrl+C at the prompt. Neither gets a
        # PS0, and both leave that prompt one row above this one. An empty
        # Enter counts as success; Ctrl+C is 130 and counts as a failure.
        if [ "$status" -eq 130 ]; then
            _wr_paint "$((now - 1))" "$_wr_accent"
        else
            _wr_paint "$((now - 1))" "$_wr_signal"
        fi
    fi

    # 2. Remember where this prompt is going.
    local wd
    if [ "$PWD" = "$HOME" ]; then
        wd='~'
    else
        wd=${PWD##*/}
        [ -n "$wd" ] || wd=/
    fi
    # **Identity, re-read on every prompt.** `\u` and `\h` are bash's own
    # escapes and cannot be overridden, so the strings are substituted
    # instead -- which is also what lets demo mode mask a terminal that was
    # already open when the recording started, with no restart. The shell
    # publishes the value; without it this is exactly what it always was.
    local _wr_who=${USER} _wr_host=${HOSTNAME%%.*} _wr_ident
    _wr_ident=$(sed -n "s/^PROMPT_IDENT='\(.*\)'\$/\1/p" \
        "${XDG_CACHE_HOME:-$HOME/.cache}/wrayth/status" 2> /dev/null | head -1)
    # Anything but the characters a name can hold is dropped: this string is
    # pasted into PS1, where a stray backslash or $ would be interpreted.
    _wr_ident=${_wr_ident//[^A-Za-z0-9@._-]/}
    if [ -n "$_wr_ident" ]; then
        _wr_who=${_wr_ident%%@*}
        _wr_host=${_wr_ident#*@}
    fi

    local plain="[${_wr_who}@${_wr_host} ${wd}]"
    _wr_col=$(( ${#plain} + 1 ))
    # A prompt that wraps does not have its sigil on the row we recorded.
    [ $(( _wr_col + 1 )) -le "${COLUMNS:-80}" ] || _wr_col=
    _wr_row=$now
    _wr_after=
    _wr_ran=0

    local e=$'\e'
    local dim="\[${e}[${_wr_dim}m\]"
    local accent="\[${e}[${_wr_accent}m\]"
    local text="\[${e}[${_wr_text}m\]"
    local alert="\[${e}[${_wr_alert}m\]"
    local bright="\[${e}[${_wr_bright}m\]"
    local off="\[${e}[0m\]"

    # **Three sigil states, three colours, none of them shared.** `alert`
    # while the line is yours, `signal` once its command has succeeded, accent
    # when it failed. The live sigil was the accent once -- the same colour a
    # failure turns -- so the line you were typing on and the last thing that
    # went wrong looked identical and the sigil said nothing.
    PS1="${dim}[${accent}${_wr_who}${dim}@${text}${_wr_host} ${bright}\W${dim}]${alert}${_wr_sigil}${off} "
}
PROMPT_COMMAND=_wrayth_prompt
[ "$_wr_twopass" = 1 ] && PS0='${ _wrayth_submit; }'

# Clear the screen and scrollback and reprint the greeting, in place. This is
# what `wrayth-deck-refresh` sends: the terminal is never restarted, so the
# window, its size, its place on the deck and the deck itself are all untouched.
_wrayth_refresh() {
    printf '\033[H\033[2J\033[3J'
    _wrayth_fetch
}

_wrayth_fetch() {
    local conf="${XDG_CONFIG_HOME:-$HOME/.config}/wrayth"
    local cfg="$conf/fastfetch.jsonc"

    command -v fastfetch > /dev/null 2>&1 || return
    [ -r "$cfg" ] || return

    local args=(--config "$cfg")

    # The emblem: a generated raw logo file carrying per-character truecolour.
    # wrayth-profile regenerates it whenever the profile changes, so there
    # is nothing to decide here -- only which of the two sizes fits.
    local cache="${XDG_CACHE_HOME:-$HOME/.cache}/wrayth"
    local emblem="$cache/emblem.raw"
    # The deck terminal waits (up to 3 s) for an emblem still being made,
    # rather than print fastfetch's plain logo.
    if [ "${WRAYTH_DECK:-0}" = 1 ]; then
        local waited=0
        while [ ! -s "$emblem" ] && [ "$waited" -lt 30 ]; do
            sleep 0.1
            waited=$((waited + 1))
        done
    fi
    if [ -r "$emblem" ]; then
        # The full logo is never squashed. On a window too short to hold it
        # along with the blank lines and the prompt, the small variant is used
        # instead -- scrolling the greeting off the top is the one outcome
        # worth avoiding.
        local rows=${LINES:-0}
        [ "$rows" -gt 0 ] || rows=$(tput lines 2> /dev/null || echo 24)
        local tall
        tall=$(wc -l < "$emblem")
        if [ "$rows" -lt $((tall + 4)) ] && [ -r "$cache/emblem-small.raw" ]; then
            emblem="$cache/emblem-small.raw"
        fi
        args+=(--logo-type file-raw --logo "$emblem")
    fi

    # The welcome message goes *inside* the fetch, in the info column, so the
    # logo keeps its height and the prompt lands right under it. fastfetch's
    # `custom` module expands {$VAR}, so the lines are handed over as
    # environment variables rather than printed afterwards.
    #
    # Called by absolute path: ~/.local/bin is only on PATH because the block
    # above put it there, and that block does not run in every shell that might
    # source a piece of this file.
    local welcome="$HOME/.local/bin/wrayth-welcome"
    if [ -x "$welcome" ]; then
        local assignments
        assignments=$("$welcome" --env 2> /dev/null)
        [ -n "$assignments" ] && eval "$assignments"
        export NR_WELCOME_1 NR_WELCOME_2 NR_WELCOME_3 NR_WELCOME_4 NR_WELCOME_5
    fi

    # The fetch header. `fastfetch`'s title module expands {$VAR}, and the
    # shell keeps the value in the status cache so demo mode can mask it for a
    # recording -- otherwise a showcase video carries `user@hostname` in 20 px
    # type directly above the prompt. One line is read rather than the file
    # sourced, so nothing else in it leaks into this shell.
    local title
    title=$(sed -n "s/^FETCH_TITLE='\(.*\)'\$/\1/p" "$cache/status" 2> /dev/null | head -1)
    export WR_TITLE="${title:-${USER}@$(uname -n)}"

    printf '\n'
    fastfetch "${args[@]}"
    printf '\n'
}

# The deck terminal gets the fetch. **An ordinary terminal gets nothing**:
# the one-line TTY/clock/queue/vuln readout that used to print here said
# nothing the bar was not already saying, and it cost a line and a blank line
# at the top of every shell.
if [ "${WRAYTH_DECK:-0}" = "1" ]; then
    _wrayth_fetch
fi
