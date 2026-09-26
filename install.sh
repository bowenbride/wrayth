#!/usr/bin/env bash
#
# install.sh -- install wrayth, in one command.
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/bowenbride/wrayth/main/install.sh)
#
#   (That fetches this file from wrayth's repository and runs it; it then
#   clones the repository itself, below.)
#   From a local copy (a git repository, or a plain folder of wrayth's files):
#       bash /path/to/install.sh --source /path/to/wrayth
#
# Want to read it first? Clone the repository, read install.sh, then run it
# from the clone:
#       git clone https://github.com/bowenbride/wrayth.git ~/wrayth-src
#       less ~/wrayth-src/install.sh
#       bash ~/wrayth-src/install.sh --source ~/wrayth-src
#
# It asks nothing it does not have to. It:
#
#   1. installs any missing packages from the official Arch repositories, with
#      ONE visible `sudo pacman -S --needed ...` command that it prints first --
#      sudo asks for your password; that is the only thing that runs as root;
#   2. fetches wrayth into ~/.config/quickshell/wrayth (from wrayth's own
#      repository, or from --source) -- nothing else is downloaded, and nothing
#      from anywhere else is run;
#   3. sets up everything else as you: wrayth's folders (owner-only), the
#      wrayth-* helpers in ~/.local/bin, the kitty and hypridle configs, the
#      bundled Chakra Petch font, the six preset wallpapers in
#      ~/Pictures/wallpapers/wrayth, one line in ~/.bashrc, and Hyprland:
#        - no Hyprland config yet, or only Hyprland's own generated default,
#          or an old-style hyprland.conf: wrayth's complete setup is installed
#          (anything already in ~/.config/hypr is first moved to a dated
#          backup folder);
#        - your own hyprland.lua: it is backed up, and one line that loads
#          wrayth is added to it.
#
# Nothing of yours is ever deleted: every file it replaces is backed up first,
# and the summary says where. Running it again updates wrayth safely: your data
# in ~/.config/wrayth is left alone, and a config you have edited (kitty.conf,
# hypr-wrayth.lua, ...) is never overwritten -- Wrayth's new version is saved
# beside it as <file>.wrayth-new. (~/.local/bin/wrayth-update does the same
# from the existing install, without re-running this.)
# `~/.config/quickshell/wrayth/install.sh --uninstall` reverses it and offers
# to put your backups back.

set -u

# wrayth's own repository, fetched when no --source is given. It is the only
# network address this installer ever uses (pacman's own mirrors aside).
WRAYTH_REPO="https://github.com/bowenbride/wrayth.git"

CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}"
BIN="$HOME/.local/bin"
FONTDIR="$HOME/.local/share/fonts/chakra-petch"
ICONFONTDIR="$HOME/.local/share/fonts/material-symbols-sharp"
ICONFONT="MaterialSymbolsSharp[FILL,GRAD,opsz,wght].ttf"
QS_TARGET="$CONFIG/quickshell/wrayth"
HYPR_DIR="$CONFIG/hypr"
HYPR_LUA="$HYPR_DIR/hyprland.lua"
HYPR_CONF="$HYPR_DIR/hyprland.conf"
HYPR_WRAYTH="$HYPR_DIR/hypr-wrayth.lua"
STATE_DIR="$HOME/.local/state/wrayth"
CACHE_DIR="$HOME/.cache/wrayth"
MANIFEST="$STATE_DIR/install.env"
BASHRC="$HOME/.bashrc"
WALLPAPER_DIR="$HOME/Pictures/wallpapers/wrayth"
STAMP="$(date +%Y%m%d-%H%M%S)"

# What the complete setup's hyprland.lua says about itself.
COMPLETE_MARK="wrayth's complete Hyprland setup"
# The two lines added to a user's own hyprland.lua, and the one to ~/.bashrc.
REQUIRE_COMMENT='-- wrayth (added by install.sh; install.sh --uninstall removes it)'
REQUIRE_LINE='require("hypr-wrayth")'
BASH_LINE='[ -r ~/.config/quickshell/wrayth/external/wrayth.bash ] && . ~/.config/quickshell/wrayth/external/wrayth.bash  # wrayth'

# The helpers, linked into ~/.local/bin. Everything that runs them uses the
# full path, so ~/.local/bin does not have to be on anybody's PATH.
BIN_SCRIPTS=(wrayth-profile wrayth-deck-reset wrayth-deck-refresh wrayth-fetch
             wrayth-welcome wrayth-daemon wrayth-emblem wrayth-wallpaper
             wrayth-unread wrayth-shell wrayth-recover wrayth-update wrayth-clip)

# The configs Wrayth installs as the user's own copies: destination|shipped
# file|name. They are copies, not links into the checkout, so an edit is made
# to the user's file and never to Wrayth's -- and an update can tell an edited
# copy from an untouched one by comparing it with the version Wrayth shipped
# before. See place_config.
CONFIG_FILES=("$CONFIG/kitty/kitty.conf|external/kitty.conf|kitty.conf"
              "$CONFIG/kitty/tab_bar.py|external/tab_bar.py|kitty tab_bar.py"
              "$HYPR_WRAYTH|external/hypr-wrayth.lua|hypr-wrayth.lua"
              "$HYPR_DIR/hypridle.conf|external/hypridle.conf|hypridle.conf")
# Two files the helpers read from ~/.config/wrayth when the user has put their
# own copy there, and otherwise from the checkout. Older installs linked them
# there; see settle_override.
OVERRIDE_FILES=("$CONFIG/wrayth/fastfetch.jsonc|external/fastfetch.jsonc|fastfetch.jsonc"
                "$CONFIG/wrayth/emblem-fallback.txt|external/emblem-fallback.txt|emblem-fallback.txt")

# Packages, all from the official repositories. REQUIRED: the shell does not
# work without them. RECOMMENDED: features that degrade gracefully without
# them, installed in the same one command because a desktop should simply
# work. (power-profiles-daemon and ufw are deliberately left out: they can
# conflict with what a machine already runs. wrayth works without them.)
REQUIRED=(quickshell hyprland kitty networkmanager pipewire wireplumber python
          python-pillow python-gobject fontconfig ttf-jetbrains-mono
          ttf-jetbrains-mono-nerd noto-fonts-cjk
          grim wl-clipboard polkit
          xdg-desktop-portal-hyprland xdg-desktop-portal-gtk)
RECOMMENDED=(cava fastfetch pacman-contrib arch-audit brightnessctl bluez
             bluez-utils hypridle hyprsunset wf-recorder inotify-tools xdg-utils)

say()  { printf '%s\n' "$*"; }
step() { printf '\n== %s ==\n' "$*"; }
ok()   { printf '  ok    %s\n' "$*"; }
did()  { printf '  %-6s %s\n' "$1" "$2"; DONE+=("$2"); }
skip() { printf '  skip  %s\n' "$*"; }
warn() { printf '  note  %s\n' "$*"; }

DONE=()
BACKUPS=()
LINKED=0

die() {
    say ""
    for line in "$@"; do say "$line"; done
    exit 1
}

# Yes/no, default no -- used only by --uninstall, the one place a question is
# needed. Reads the terminal, so it works when this script itself arrived on
# stdin; with no terminal the answer is no.
ask() {
    local reply=""
    printf '  %s [y/N] ' "$1"
    read -r reply 2>/dev/null < /dev/tty || { reply=""; printf '\n'; }
    case "$reply" in y | Y | yes | YES) return 0 ;; *) return 1 ;; esac
}

# True when $1 already resolves to the same file as $2.
same() {
    local a b
    a="$(readlink -f "$1" 2>/dev/null)" || return 1
    b="$(readlink -f "$2" 2>/dev/null)" || return 1
    [ -n "$a" ] && [ "$a" = "$b" ]
}

# The manifest is KEY='value' lines, written only by this script and read back
# with sed, never sourced, so a hand edit cannot run anything.
manifest_get() {
    [ -f "$MANIFEST" ] || return 0
    sed -n "s/^$1='\(.*\)'\$/\1/p" "$MANIFEST" | tail -1
}
manifest_set() {
    mkdir -p -m 700 "$STATE_DIR" 2>/dev/null || mkdir -p "$STATE_DIR"
    local tmp="$MANIFEST.tmp"
    { [ -f "$MANIFEST" ] && grep -v "^$1=" "$MANIFEST"; printf "%s='%s'\n" "$1" "$2"; } > "$tmp"
    mv "$tmp" "$MANIFEST"
}
# Every backup is recorded as original|backup, so --uninstall can offer to put
# each one back.
record_backup() {
    local n
    n=$(grep -c '^BACKUP_' "$MANIFEST" 2>/dev/null)
    manifest_set "BACKUP_$((${n:-0} + 1))" "$1|$2"
    BACKUPS+=("$1  ->  $2")
}

# Move something of the user's out of the way, dated, never deleted.
back_up() {
    local path=$1 backup="$1.wrayth-backup-$STAMP"
    mv "$path" "$backup"
    record_backup "$path" "$backup"
}

# Link $1 to $2. Anything else already at $1 is backed up first.
link_to() {
    local link=$1 src=$2 desc=$3
    if same "$link" "$src"; then
        ok "$desc"
        return
    fi
    mkdir -p "$(dirname "$link")"
    if [ -L "$link" ] && [[ "$(readlink "$link")" == */quickshell/wrayth/* ]]; then
        rm -f "$link" # an older wrayth link, not the user's file
    elif [ -e "$link" ] || [ -L "$link" ]; then
        back_up "$link"
    fi
    ln -sfn "$src" "$link"
    printf '  %-6s %s\n' link "$desc"
    LINKED=$((LINKED + 1))
}

# Remove a link only if it is a symlink into wrayth, so uninstall never deletes
# a file the user put there, nor the checkout itself.
unlink_ours() {
    local link=$1 src=$2 desc=$3
    if [ -L "$link" ] && same "$link" "$src"; then
        rm -f "$link"
        did rm "$desc"
    fi
}

# Take out exactly what the installer appended to a file -- the blank line
# before it included -- so the file is left as it was.
strip_added() {
    python3 - "$1" "$2" <<'PY'
import sys
path, block = sys.argv[1], sys.argv[2]
text = open(path).read()
for piece in ("\n" + block + "\n", block + "\n", block):
    if piece in text:
        text = text.replace(piece, "", 1)
        break
open(path, "w").write(text)
PY
}

has_require() {
    [ -f "$1" ] && grep -Eq '^[[:space:]]*require[[:space:]]*\(?[[:space:]]*["'"'"']hypr-wrayth["'"'"']' "$1"
}

is_generated_default() {
    grep -Eq '^[[:space:]]*hl\.config\(\{[[:space:]]*autogenerated[[:space:]]*=[[:space:]]*true' "$1" 2>/dev/null
}

# --------------------------------------------------------------------------
# Updating a config without ever overwriting the user's edits.
#
# PREV is the checkout this run replaced (stage 1 moves it aside), and
# WRAYTH_BASELINE_REF the commit wrayth-update updated the checkout from. Either
# says what Wrayth shipped before, which is how an edited copy is told from an
# untouched one.
PREV="${WRAYTH_PREVIOUS:-}"
EDITED=()
SCRATCH="" # made at the start of stage 2

# Writes the version of <rel> Wrayth shipped before this run to <out>; fails
# when that is not known. `trust-folder`: a plain-folder install's previous copy
# counts as what was shipped -- true once configs are copies (nobody edits the
# checkout), not for an older install whose links led edits into it.
shipped_before() {
    local rel=$1 out=$2
    if [ -n "${WRAYTH_BASELINE_REF:-}" ]; then
        git -C "$SRC" show "$WRAYTH_BASELINE_REF:$rel" > "$out" 2>/dev/null && return 0
    elif [ -n "$PREV" ] && [ -d "$PREV/.git" ]; then
        git -C "$PREV" show "HEAD:$rel" > "$out" 2>/dev/null && return 0
    elif [ -n "$PREV" ] && [ -f "$PREV/$rel" ] && [ "${3:-}" = trust-folder ]; then
        cp "$PREV/$rel" "$out" && return 0
    fi
    rm -f "$out"
    return 1
}

# The user's edits, if an older install's link into the checkout led them into
# the checkout this run replaced: prints that file, or nothing.
edits_through_link() {
    local rel=$1 base="$SCRATCH/base"
    [ -n "$PREV" ] && [ -f "$PREV/$rel" ] || return 0
    if shipped_before "$rel" "$base"; then
        cmp -s "$PREV/$rel" "$base" || printf '%s' "$PREV/$rel"
    elif ! cmp -s "$PREV/$rel" "$SRC/$rel"; then
        printf '%s' "$PREV/$rel" # cannot tell whether it was edited: keep it
    fi
}

# Puts Wrayth's current <rel> at <dest>, unless the user has edited <dest>:
#   - missing: copied;
#   - the same as Wrayth's current version: nothing to do;
#   - untouched since Wrayth shipped it: replaced with the new version;
#   - edited: left exactly as it is, and when Wrayth's version has changed the
#     new one is saved beside it as <dest>.wrayth-new, and the summary says so.
# On a first install, a file that predates Wrayth is backed up and replaced.
place_config() {
    local dest=$1 rel=$2 desc=$3 new="$SRC/$2" base="$SCRATCH/base" theirs=""
    mkdir -p "$(dirname "$dest")"
    if [ -L "$dest" ] && [[ "$(readlink "$dest")" == */quickshell/wrayth/* ]]; then
        # An older install's link into the checkout, turned into a copy.
        theirs="$(edits_through_link "$rel")"
        rm -f "$dest"
        if [ -z "$theirs" ]; then
            cp "$new" "$dest"
            did copy "$desc (now a file of your own)"
            return
        fi
        cp "$theirs" "$dest"
    elif [ ! -e "$dest" ] && [ ! -L "$dest" ]; then
        cp "$new" "$dest"
        did copy "$desc"
        return
    elif [ "$FRESH" = 1 ]; then
        back_up "$dest"
        cp "$new" "$dest"
        did copy "$desc"
        return
    fi
    if cmp -s "$dest" "$new"; then
        ok "$desc"
        return
    fi
    if [ -z "$theirs" ] && shipped_before "$rel" "$base" trust-folder && cmp -s "$dest" "$base"; then
        cp "$new" "$dest"
        did update "$desc"
        return
    fi
    if shipped_before "$rel" "$base" trust-folder && cmp -s "$base" "$new"; then
        ok "$desc (your edited copy; Wrayth's has not changed)"
        return
    fi
    cp "$new" "$dest.wrayth-new"
    EDITED+=("$dest")
    warn "$desc: kept your edited copy; Wrayth's new version is beside it"
}

# fastfetch.jsonc and emblem-fallback.txt: read from ~/.config/wrayth when the
# user has their own copy there, else from the checkout (which updates). An
# older install linked the shipped file there: the link goes, and edits made
# through it are kept as the user's own copy.
settle_override() {
    local dest=$1 rel=$2 desc=$3 theirs
    [ -L "$dest" ] && [[ "$(readlink "$dest")" == */quickshell/wrayth/* ]] || return 0
    theirs="$(edits_through_link "$rel")"
    rm -f "$dest"
    if [ -n "$theirs" ]; then
        cp "$theirs" "$dest"
        did keep "your edited $desc, now a file of your own in ~/.config/wrayth"
    else
        did rm "the $desc link in ~/.config/wrayth (Wrayth's own is used, and updates)"
    fi
}

# Uninstall: a config is removed only when it is Wrayth's, unedited.
remove_our_config() {
    local dest=$1 rel=$2 desc=$3 src=$4
    if [ -L "$dest" ] && same "$dest" "$src/$rel"; then
        rm -f "$dest"
        did rm "$desc"
    elif [ -f "$dest" ] && [ ! -L "$dest" ] && cmp -s "$dest" "$src/$rel"; then
        rm -f "$dest"
        did rm "$desc"
    elif [ -e "$dest" ]; then
        skip "$desc: your edited copy is left at $dest"
    fi
    rm -f "$dest.wrayth-new"
}

# --------------------------------------------------------------------------
uninstall() {
    say "Removing wrayth. Your settings (~/.config/wrayth), wallpapers and the"
    say "wrayth folder itself are kept; delete them by hand if you want them gone."

    local src="$QS_TARGET"

    step "Hyprland"
    if [ -f "$HYPR_LUA" ] && grep -qF "$COMPLETE_MARK" "$HYPR_LUA"; then
        # Moved aside, not deleted (you may have edited it). Hyprland makes a
        # fresh default config at its next start, unless your old one is put
        # back below.
        mv "$HYPR_DIR" "$CONFIG/hypr.wrayth-removed-$STAMP"
        did move "wrayth's Hyprland config to $CONFIG/hypr.wrayth-removed-$STAMP"
    elif has_require "$HYPR_LUA"; then
        strip_added "$HYPR_LUA" "$REQUIRE_COMMENT"$'\n'"$REQUIRE_LINE"
        did edit "removed wrayth's line from $HYPR_LUA"
    fi
    remove_our_config "$HYPR_WRAYTH" external/hypr-wrayth.lua "hypr-wrayth.lua" "$src"
    remove_our_config "$HYPR_DIR/hypridle.conf" external/hypridle.conf "hypridle.conf" "$src"

    step "~/.bashrc"
    if [ -f "$BASHRC" ] && grep -qxF "$BASH_LINE" "$BASHRC"; then
        strip_added "$BASHRC" "$BASH_LINE"
        did edit "removed wrayth's line from $BASHRC"
    fi

    step "Helpers, links and font"
    for s in "${BIN_SCRIPTS[@]}"; do unlink_ours "$BIN/$s" "$src/external/$s" "bin/$s"; done
    unlink_ours "$CONFIG/wrayth/fastfetch.jsonc"     "$src/external/fastfetch.jsonc"     "fastfetch.jsonc"
    unlink_ours "$CONFIG/wrayth/emblem-fallback.txt" "$src/external/emblem-fallback.txt" "emblem-fallback.txt"
    # The colours go with a kitty.conf that is Wrayth's; an edited one is the
    # user's, and may still include them.
    if { same "$CONFIG/kitty/kitty.conf" "$src/external/kitty.conf" || cmp -s "$CONFIG/kitty/kitty.conf" "$src/external/kitty.conf"; } &&
        [ -f "$CONFIG/kitty/wrayth-colors.conf" ]; then
        rm -f "$CONFIG/kitty/wrayth-colors.conf"
        did rm "kitty colours"
    fi
    remove_our_config "$CONFIG/kitty/kitty.conf" external/kitty.conf "kitty.conf" "$src"
    remove_our_config "$CONFIG/kitty/tab_bar.py" external/tab_bar.py "kitty tab_bar.py" "$src"
    if [ -d "$FONTDIR" ]; then
        rm -f "$FONTDIR"/ChakraPetch-*.ttf "$FONTDIR/OFL.txt"
        rmdir "$FONTDIR" 2>/dev/null || true
        command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1
        did rm "Chakra Petch font"
    fi
    if [ -d "$ICONFONTDIR" ]; then
        rm -f "$ICONFONTDIR/$ICONFONT" "$ICONFONTDIR/LICENSE"
        rmdir "$ICONFONTDIR" 2>/dev/null || true
        command -v fc-cache >/dev/null 2>&1 && fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1
        did rm "Material Symbols Sharp icon font"
    fi

    step "Your backups"
    local restorable=()
    while IFS= read -r line; do
        local pair orig backup
        pair="$(printf '%s' "$line" | sed "s/^[^=]*='\(.*\)'\$/\1/")"
        orig="${pair%%|*}"
        backup="${pair#*|}"
        [ -e "$backup" ] || [ -L "$backup" ] || continue
        restorable+=("$orig|$backup")
        say "  $backup"
        say "      was $orig"
    done < <(grep '^BACKUP_' "$MANIFEST" 2>/dev/null)
    if [ "${#restorable[@]}" -eq 0 ]; then
        ok "none to put back"
    elif ask "Put these back where they were?"; then
        for pair in "${restorable[@]}"; do
            local orig="${pair%%|*}" backup="${pair#*|}"
            if [ -f "$orig" ] && [ ! -L "$orig" ] && cmp -s "$orig" "$backup"; then
                rm -f "$backup" # already exactly as it was
                did restore "$orig"
                continue
            fi
            if [ -L "$orig" ]; then
                rm -f "$orig"
            elif [ -e "$orig" ]; then
                mv "$orig" "$orig.wrayth-removed-$STAMP"
                say "  (wrayth's $orig is kept at $orig.wrayth-removed-$STAMP)"
            fi
            mv "$backup" "$orig"
            did restore "$orig"
        done
    else
        skip "backups left where they are"
    fi

    rm -f "$MANIFEST"
    say ""
    say "Done. Log out and back in to finish."
    exit 0
}

# --------------------------------------------------------------------------
SOURCE=""
STAGE2=0
UPDATE_FROM=""
while [ $# -gt 0 ]; do
    case "$1" in
        -u | --uninstall) uninstall ;;
        -h | --help)
            sed -n '2,45p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        --source)
            [ $# -ge 2 ] || die "--source needs a path or URL."
            SOURCE="$2"
            shift
            ;;
        --stage2) STAGE2=1 ;;
        # Run by wrayth-update, after it has moved the checkout on from <ref>:
        # packages, then the setup, touching nothing of the user's. See
        # UPDATING below.
        --update-from)
            [ $# -ge 2 ] || die "--update-from needs a commit."
            UPDATE_FROM="$2"
            shift
            ;;
        *) die "Unknown option: $1  (try --help)" ;;
    esac
    shift
done

if [ "$(id -u)" = 0 ]; then
    die "Run this as yourself, not as root (and not with sudo). It asks for your" \
        "password only for the one package-install step."
fi

# Any of wrayth's packages that are missing, in one visible `sudo pacman -S`
# command; sudo asks for the password. Used by stage 1 and by updates.
install_packages() {
    step "1. Packages"
    command -v pacman >/dev/null 2>&1 ||
        die "wrayth is built for Arch Linux (pacman was not found), so it cannot be installed here."
    local missing=() still=() p
    for p in "${REQUIRED[@]}" "${RECOMMENDED[@]}"; do
        pacman -Qq "$p" >/dev/null 2>&1 || missing+=("$p")
    done
    [ "${KIND:-git}" = git ] && ! command -v git >/dev/null 2>&1 && missing+=(git)
    if [ "${#missing[@]}" -eq 0 ]; then
        ok "everything wrayth needs is installed"
        return
    fi
    say "  wrayth needs these packages from the official Arch repositories:"
    say "      ${missing[*]}"
    say "  Installing them with this command -- sudo will ask for your password:"
    say ""
    say "      sudo pacman -S --needed ${missing[*]}"
    say ""
    if sudo pacman -S --needed "${missing[@]}"; then
        did install "${missing[*]}"
        return
    fi
    for p in "${REQUIRED[@]}"; do pacman -Qq "$p" >/dev/null 2>&1 || still+=("$p"); done
    [ "${KIND:-git}" = git ] && ! command -v git >/dev/null 2>&1 && still+=(git)
    if [ "${#still[@]}" -gt 0 ]; then
        die "The packages were not installed, and wrayth cannot run without these:" \
            "    ${still[*]}" \
            "If your account cannot use sudo, ask whoever looks after this computer" \
            "to run the command above, then run this again."
    fi
    warn "some optional packages were not installed; wrayth works without them"
}

# ==========================================================================
# Stage 1: packages, then fetch wrayth, then hand over to the fetched copy.
# ==========================================================================
if [ "$STAGE2" = 0 ] && [ -z "$UPDATE_FROM" ]; then
    say "Installing wrayth."

    # Where wrayth comes from. A folder holding wrayth's files is copied; a git
    # repository (a path or an https URL) is cloned.
    SELF_DIR=""
    if [ -n "${BASH_SOURCE[0]:-}" ] && [ -f "${BASH_SOURCE[0]}" ]; then
        SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
    fi
    if [ -z "$SOURCE" ]; then
        if [ -n "$SELF_DIR" ] && [ -f "$SELF_DIR/shell.qml" ]; then
            SOURCE="$SELF_DIR"
        elif [ -n "$WRAYTH_REPO" ]; then
            SOURCE="$WRAYTH_REPO"
        else
            die "Where should wrayth come from? Its repository is not published yet," \
                "so run this with --source and the path of a copy of wrayth:" \
                "    bash install.sh --source /path/to/wrayth"
        fi
    fi
    case "$SOURCE" in
        https://* | http://* | git@* | ssh://* | file://*) KIND=git ;;
        *)
            SOURCE="$(cd "$SOURCE" 2>/dev/null && pwd -P)" ||
                die "Cannot read $SOURCE -- check the path, and that you can open it."
            if [ -f "$SOURCE/shell.qml" ] && [ -f "$SOURCE/install.sh" ]; then
                KIND=folder
            elif git -C "$SOURCE" rev-parse --git-dir >/dev/null 2>&1; then
                KIND=git
            else
                die "$SOURCE does not look like wrayth (no shell.qml, and not a git repository)."
            fi
            ;;
    esac

    install_packages

    step "2. Fetching wrayth"
    # Whether Wrayth was installed before this run (a first install replaces
    # what is in the way, backed up; a later run never touches an edited
    # config), and where the checkout it replaces went.
    export WRAYTH_WAS_INSTALLED="$(manifest_get INSTALLED)"
    export WRAYTH_PREVIOUS=""
    if [ "$KIND" = folder ] && same "$SOURCE" "$QS_TARGET"; then
        ok "wrayth is already at $QS_TARGET"
    else
        mkdir -p "$(dirname "$QS_TARGET")"
        if [ -e "$QS_TARGET" ] || [ -L "$QS_TARGET" ]; then
            if [ -n "$(manifest_get INSTALLED)" ] || [ -L "$QS_TARGET" ]; then
                # A copy this installer put there: replaced by the new one, the
                # old one kept once in the cache in case anything was edited.
                mkdir -p -m 700 "$CACHE_DIR"
                rm -rf "$CACHE_DIR/previous-install"
                mv "$QS_TARGET" "$CACHE_DIR/previous-install"
                WRAYTH_PREVIOUS="$CACHE_DIR/previous-install"
            else
                back_up "$QS_TARGET"
            fi
        fi
        if [ "$KIND" = git ]; then
            git clone --quiet --depth 1 "$SOURCE" "$QS_TARGET" ||
                die "Could not fetch wrayth from $SOURCE."
        else
            mkdir -p "$QS_TARGET"
            (cd "$SOURCE" && tar -cf - --exclude=./.git --exclude=./scratchpad .) | (cd "$QS_TARGET" && tar -xf -) ||
                die "Could not copy wrayth from $SOURCE."
        fi
        manifest_set INSTALLED "$KIND"
        manifest_set SOURCE "$SOURCE"
        did fetch "wrayth into $QS_TARGET"
    fi

    # The rest is done by the copy just fetched, so it is always that
    # version's own setup that runs.
    DONE_STAGE1="$(printf '%s\n' "${DONE[@]}")"
    export WRAYTH_STAGE1_DONE="$DONE_STAGE1"
    exec bash "$QS_TARGET/install.sh" --stage2
fi

# ==========================================================================
# Stage 2: set everything up. No questions; anything replaced is backed up,
# and a config the user has edited is never replaced.
#
# UPDATING (--update-from, run by wrayth-update after it has moved the
# checkout on in place): the same setup, except that it never touches
# ~/.config/wrayth, ~/.local/state/wrayth or ~/.cache/wrayth, never re-adds
# anything the user took out (the ~/.bashrc line, the line in their own
# hyprland.lua, a preset wallpaper they deleted), and backs nothing up,
# because it replaces only files that are Wrayth's and unedited.
# ==========================================================================
SRC="$QS_TARGET"
if [ -n "${WRAYTH_STAGE1_DONE:-}" ]; then
    while IFS= read -r d; do [ -n "$d" ] && DONE+=("$d"); done <<< "$WRAYTH_STAGE1_DONE"
fi
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT
UPDATING=0
if [ -n "$UPDATE_FROM" ]; then
    UPDATING=1
    export WRAYTH_BASELINE_REF="$UPDATE_FROM"
    install_packages
fi
FRESH=0
[ "$UPDATING" = 0 ] && [ -z "${WRAYTH_WAS_INSTALLED:-}" ] && FRESH=1

if [ "$UPDATING" = 0 ]; then
    step "3. Folders (owner-only)"
    for d in "$CONFIG/wrayth" "$CACHE_DIR" "$STATE_DIR"; do
        mkdir -p -m 700 "$d" 2>/dev/null || mkdir -p "$d"
        chmod 700 "$d" 2>/dev/null || true
    done
    ok "~/.config/wrayth  ~/.cache/wrayth  ~/.local/state/wrayth"
fi

step "4. Helpers and configs"
for s in "${BIN_SCRIPTS[@]}"; do
    # An update never moves a file of the user's out of the way.
    if [ "$UPDATING" = 1 ] && { [ -e "$BIN/$s" ] || [ -L "$BIN/$s" ]; } && ! same "$BIN/$s" "$SRC/external/$s" &&
        ! { [ -L "$BIN/$s" ] && [[ "$(readlink "$BIN/$s")" == */quickshell/wrayth/* ]]; }; then
        skip "bin/$s: a file of your own is there"
        continue
    fi
    link_to "$BIN/$s" "$SRC/external/$s" "bin/$s"
done
# The kitty configs here; the Hyprland ones in step 7, once it is settled
# whether ~/.config/hypr is the complete setup's.
for entry in "${CONFIG_FILES[@]}"; do
    IFS='|' read -r dest rel desc <<< "$entry"
    case "$dest" in "$HYPR_DIR"/*) continue ;; esac
    place_config "$dest" "$rel" "$desc"
done
if [ "$UPDATING" = 0 ]; then
    for entry in "${OVERRIDE_FILES[@]}"; do
        IFS='|' read -r dest rel desc <<< "$entry"
        settle_override "$dest" "$rel" "$desc"
    done
    # kitty.conf includes the per-profile colours wrayth-profile writes; made
    # once now so the first terminal opens in the right colours. The same call
    # makes the deck terminal's recoloured distro logo, which must exist
    # before the deck terminal first opens.
    if [ ! -f "$CONFIG/kitty/wrayth-colors.conf" ] || [ ! -s "$CACHE_DIR/emblem.raw" ]; then
        "$BIN/wrayth-profile" -n Circuit >/dev/null 2>&1 && did set "terminal colours and logo"
    fi
fi

step "5. Font and wallpapers"
mkdir -p "$FONTDIR"
if cmp -s "$SRC/assets/fonts/chakra-petch/ChakraPetch-Bold.ttf" "$FONTDIR/ChakraPetch-Bold.ttf" 2>/dev/null &&
    cmp -s "$SRC/assets/fonts/chakra-petch/ChakraPetch-Medium.ttf" "$FONTDIR/ChakraPetch-Medium.ttf" 2>/dev/null; then
    ok "Chakra Petch font"
else
    cp -f "$SRC/assets/fonts/chakra-petch/"ChakraPetch-*.ttf "$SRC/assets/fonts/chakra-petch/OFL.txt" "$FONTDIR/"
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1
    did copy "Chakra Petch font"
fi
# The icon font (Material Symbols Sharp, Apache 2.0, with its licence): every
# icon in the shell is a glyph from it.
mkdir -p "$ICONFONTDIR"
if cmp -s "$SRC/assets/fonts/material-symbols-sharp/$ICONFONT" "$ICONFONTDIR/$ICONFONT" 2>/dev/null; then
    ok "Material Symbols Sharp icon font"
else
    cp -f "$SRC/assets/fonts/material-symbols-sharp/$ICONFONT" "$SRC/assets/fonts/material-symbols-sharp/LICENSE" "$ICONFONTDIR/"
    fc-cache -f "$HOME/.local/share/fonts" >/dev/null 2>&1
    did copy "Material Symbols Sharp icon font"
fi
# The preset wallpapers, into the library folder the shell adopts on its first
# start. Never over a file already there -- and an update adds only presets
# that are new in this version, so one the user deleted stays deleted.
mkdir -p "$WALLPAPER_DIR"
n=0
for f in "$SRC"/assets/wallpapers/net-*.png; do
    [ -e "$WALLPAPER_DIR/$(basename "$f")" ] && continue
    if [ "$UPDATING" = 1 ] && git -C "$SRC" cat-file -e "$UPDATE_FROM:assets/wallpapers/$(basename "$f")" 2>/dev/null; then
        continue
    fi
    cp "$f" "$WALLPAPER_DIR/" && n=$((n + 1))
done
if [ "$n" -gt 0 ]; then did copy "$n wallpapers to ~/Pictures/wallpapers/wrayth"; else ok "wallpapers"; fi

if [ "$UPDATING" = 0 ]; then
    step "6. Bash"
    if [ -f "$BASHRC" ] && grep -qxF "$BASH_LINE" "$BASHRC"; then
        ok "~/.bashrc loads wrayth"
    elif [ -f "$BASHRC" ] && grep -qF -- "# --- wrayth ---" "$BASHRC"; then
        ok "~/.bashrc carries wrayth's block itself"
    else
        if [ -f "$BASHRC" ]; then
            cp -p "$BASHRC" "$BASHRC.wrayth-backup-$STAMP"
            record_backup "$BASHRC" "$BASHRC.wrayth-backup-$STAMP"
            printf '\n%s\n' "$BASH_LINE" >> "$BASHRC"
        else
            printf '%s\n' "$BASH_LINE" > "$BASHRC"
        fi
        did edit "added one line to ~/.bashrc"
    fi
fi

step "7. Hyprland"
if [ -f "$HYPR_LUA" ] && grep -qF "$COMPLETE_MARK" "$HYPR_LUA"; then
    # Wrayth's complete setup: updated like any other config -- replaced only
    # while it is exactly as Wrayth shipped it.
    [ "$UPDATING" = 0 ] && manifest_set MODE complete
    place_config "$HYPR_LUA" external/hyprland.lua "hyprland.lua (the complete setup)"
elif [ "$UPDATING" = 1 ]; then
    # The user's own config: an update never edits it.
    if has_require "$HYPR_LUA"; then ok "your hyprland.lua loads wrayth"; else skip "your hyprland.lua does not load wrayth; left as it is"; fi
elif [ -f "$HYPR_LUA" ] && ! is_generated_default "$HYPR_LUA"; then
    # Your own Lua config: backed up, and one line added, once.
    manifest_set MODE add
    if has_require "$HYPR_LUA"; then
        ok "your hyprland.lua already loads wrayth"
    else
        cp -p "$HYPR_LUA" "$HYPR_LUA.wrayth-backup-$STAMP"
        record_backup "$HYPR_LUA" "$HYPR_LUA.wrayth-backup-$STAMP"
        printf '\n%s\n%s\n' "$REQUIRE_COMMENT" "$REQUIRE_LINE" >> "$HYPR_LUA"
        did edit "added wrayth to your hyprland.lua"
    fi
else
    # No config, Hyprland's generated default, or an old hyprland.conf: the
    # complete setup, with whatever was there moved to a dated backup.
    manifest_set MODE complete
    if [ -e "$HYPR_DIR" ] && [ -n "$(ls -A "$HYPR_DIR" 2>/dev/null)" ]; then
        backup="$CONFIG/hypr.wrayth-backup-$STAMP"
        mv "$HYPR_DIR" "$backup"
        record_backup "$HYPR_DIR" "$backup"
    fi
    mkdir -p "$HYPR_DIR"
    cp "$SRC/external/hyprland.lua" "$HYPR_LUA"
    did make "wrayth's complete Hyprland setup"
fi
for entry in "${CONFIG_FILES[@]}"; do
    IFS='|' read -r dest rel desc <<< "$entry"
    case "$dest" in "$HYPR_DIR"/*) place_config "$dest" "$rel" "$desc" ;; esac
done

step "8. Screen sharing"
# xdg-desktop-portal-hyprland ships the setting that makes screen sharing work
# (Hyprland's portal first, GTK's for the rest); a portals.conf of your own
# can override it. It is only checked, never changed.
portal_note=""
for f in "$CONFIG/xdg-desktop-portal/hyprland-portals.conf" "$CONFIG/xdg-desktop-portal/portals.conf"; do
    if [ -f "$f" ] && ! grep -q 'hyprland' "$f"; then
        portal_note="$f"
    fi
done
if [ -n "$portal_note" ]; then
    warn "$portal_note does not mention hyprland, so screen sharing may not work;"
    warn "  Hyprland's own setting is: [preferred] default=hyprland;gtk"
else
    ok "xdg-desktop-portal-hyprland and -gtk"
fi

# --------------------------------------------------------------------------
say ""
VERSION_NOW="$(head -1 "$SRC/VERSION" 2>/dev/null | tr -d '[:space:]')"
if [ "$UPDATING" = 1 ]; then say "== wrayth ${VERSION_NOW:+$VERSION_NOW }is updated =="; else say "== wrayth ${VERSION_NOW:+$VERSION_NOW }is installed =="; fi
for d in "${DONE[@]}"; do say "  - $d"; done
[ "$LINKED" -gt 0 ] && say "  - linked $LINKED of wrayth's helpers and settings into place"
[ "${#DONE[@]}" -eq 0 ] && [ "$LINKED" -eq 0 ] && say "  Everything was already in place."
if [ "${#EDITED[@]}" -gt 0 ]; then
    say ""
    say "  You have edited these, so they were left exactly as they are. Wrayth's"
    say "  new version of each is saved beside it; compare, and take what you want:"
    for e in "${EDITED[@]}"; do
        say "    $e"
        say "      new: $e.wrayth-new     (diff \"$e\" \"$e.wrayth-new\")"
    done
fi
if [ "${#BACKUPS[@]}" -gt 0 ]; then
    say ""
    say "  Your previous files are kept here:"
    for b in "${BACKUPS[@]}"; do say "    $b"; done
fi
if [ "$UPDATING" = 0 ]; then
    say ""
    say "  Next: log out and log back in to Hyprland. (On a text console: log in and"
    say "  type  start-hyprland )"
    say ""
    say "  To update later:        ~/.local/bin/wrayth-update"
    say "  To remove wrayth later: ~/.config/quickshell/wrayth/install.sh --uninstall"
fi
