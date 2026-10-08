pragma Singleton

import QtQuick
import Quickshell

// The icon font, loaded by the shell itself from its bundled file
// (DESIGN.md section 5), so icons work whether or not Material Symbols Sharp
// is installed system-wide or the font cache is current.
//
// **Why it is not left to fontconfig.** Qt reads the system's font list once,
// when the process starts. An update's `git merge` hot-reloads the new QML
// into the running shell before install.sh has copied the font, so that
// process never saw it and drew every icon's name as text ("inbox",
// "chevron_r") until a real restart; and a font installed where fontconfig
// does not look (XDG_DATA_HOME set elsewhere) was never found at all.
// Measured offscreen: "inbox" 41.6 px wide (the letters) in either case, 16 px
// (one glyph) from this loader with no font installed anywhere.
Singleton {
    id: root

    readonly property string file: Quickshell.shellPath("assets/fonts/material-symbols-sharp/MaterialSymbolsSharp[FILL,GRAD,opsz,wght].ttf")
    // Ready to draw with: Icon draws nothing until then, never the name.
    readonly property bool ready: loader.status === FontLoader.Ready && loader.name !== ""
    readonly property string family: ready ? loader.name : ""

    FontLoader {
        id: loader

        // The brackets and commas in the file name must be escaped, or the
        // URL does not resolve and nothing loads.
        source: "file://" + encodeURI(root.file).replace(/\[/g, "%5B").replace(/\]/g, "%5D").replace(/,/g, "%2C")
        onStatusChanged: if (status === FontLoader.Error) root.warn(`could not load ${root.file}`)
    }

    // One warning for the whole shell, however many icons are affected.
    property bool _warned: false
    function warn(why: string): void {
        if (_warned)
            return;
        _warned = true;
        console.warn(`Icon font unavailable (${why}): icons are drawn as nothing until it loads.`);
    }
}
