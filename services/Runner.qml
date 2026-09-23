pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Who is at the keyboard: the two-character `code` the bar's ID block shows and
// the `handle` the deck terminal's welcome message greets. Both are derived from
// the username when the file is missing or a key is absent, so the shell works
// before anyone has written one.
Singleton {
    id: root

    readonly property string user: Quickshell.env("USER") || Quickshell.env("LOGNAME") || "runner"

    // First two letters of the username, uppercased. Padded rather than left
    // short: the block draws two characters whatever the name is.
    readonly property string defaultCode: (user.slice(0, 2).toUpperCase() + "00").slice(0, 2)
    readonly property string defaultHandle: user.charAt(0).toUpperCase() + user.slice(1)

    readonly property string defaultSuffix: "01"

    property string code: defaultCode
    property string suffix: defaultSuffix

    property string handle: defaultHandle

    readonly property string initialContents: `# wrayth runner identity
# code:   exactly two characters, A-Z or 0-9. The bar's ID block, before the //.
# suffix: exactly two characters, A-Z or 0-9. The bar's ID block, after the //.
# handle: the name the deck terminal greets. Never shown on the bar.
code=${defaultCode}
suffix=${defaultSuffix}
handle=${defaultHandle}
`

    // Written through a temporary file and renamed into place. A rename inside
    // a filesystem is atomic, so an interruption mid-save leaves either the old
    // file or the new one and never a half-written config -- this is the one
    // thing on the bar the user owns, and it has to survive a power cut.
    // Both halves in one write: they are edited together in one grid, and a
    // partial save could leave a new code beside an old suffix.
    function saveIdent(nextCode: string, nextSuffix: string): void {
        const code2 = nextCode.toUpperCase();
        const suffix2 = nextSuffix.toUpperCase();
        if (!_validCode(code2) || !_validCode(suffix2))
            return;
        code = code2;
        suffix = suffix2;
        writer.command = ["sh", "-c", `set -e; d=$(dirname "$1"); mkdir -p "$d"; t=$(mktemp "$1.XXXXXX"); printf '%s\n' "$2" > "$t"; chmod 644 "$t"; mv -f "$t" "$1"`, "sh", Paths.runnerFile, _serialise(code2, suffix2)];
        writer.running = true;
    }

    // The whole file, so the rename replaces it wholesale rather than patching
    // a line in place. Any keys the user added are preserved.
    function _serialise(nextCode: string, nextSuffix: string): string {
        const lines = [];
        let sawCode = false;
        let sawSuffix = false;
        for (const line of _raw.split("\n")) {
            if (/^[\s]*code[\s]*=/.test(line)) {
                lines.push(`code=${nextCode}`);
                sawCode = true;
            } else if (/^[\s]*suffix[\s]*=/.test(line)) {
                lines.push(`suffix=${nextSuffix}`);
                sawSuffix = true;
            } else if (line !== "" || lines.length === 0) {
                lines.push(line);
            }
        }
        if (!sawCode)
            lines.push(`code=${nextCode}`);
        if (!sawSuffix)
            lines.push(`suffix=${nextSuffix}`);
        return lines.join("\n");
    }

    property string _raw: initialContents

    Process {
        id: writer
    }

    // Exactly two characters, A-Z or 0-9. Anything else falls back to the
    // default rather than being drawn wrong -- the block has room for two and
    // its width is measured from them.
    function _validCode(value: string): bool {
        return /^[A-Z0-9]{2}$/.test(value);
    }

    function _parse(contents: string): void {
        let nextCode = defaultCode;
        let nextSuffix = defaultSuffix;
        let nextHandle = defaultHandle;
        for (const line of contents.split("\n")) {
            if (line.trim().startsWith("#"))
                continue;
            const split = line.indexOf("=");
            if (split < 0)
                continue;
            const key = line.slice(0, split).trim().toLowerCase();
            const value = line.slice(split + 1).trim();
            if (!value)
                continue;
            if (key === "code") {
                const upper = value.toUpperCase();
                if (_validCode(upper))
                    nextCode = upper;
            } else if (key === "suffix") {
                const upper = value.toUpperCase();
                if (_validCode(upper))
                    nextSuffix = upper;
            } else if (key === "handle") {
                nextHandle = value;
            }
        }
        code = nextCode;
        suffix = nextSuffix;
        handle = nextHandle;
    }

    FileView {
        path: Paths.runnerFile
        watchChanges: true
        printErrors: false

        onLoaded: {
            root._raw = text();
            root._parse(text());
        }
        onFileChanged: reload()
        onLoadFailed: error => {
            // Seeded rather than left absent, so the file is there to be found
            // and edited. The defaults it carries are the ones already in use.
            if (error === FileViewError.FileNotFound)
                setText(root.initialContents);
        }
    }
}
