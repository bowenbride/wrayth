pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// The shell's two atmosphere settings -- the glitch schedule and the scanline
// treatment -- and where they are kept.
//
// **They live with the profile settings**, in `~/.config/wrayth/effects.json`
// beside `profile`, `custom-profiles.json` and `wallpapers.json`, watched and
// hand-editable like the rest of them. Not in `~/.local/state/wrayth/`:
// state there is what the shell works out for itself -- the idle inhibitor,
// launch counts -- and this is something the user chose.
Singleton {
    id: root

    // --- Scanline treatments --------------------------------------------------
    // **The strengths came down twice after they were seen on a screen.**
    // The first pass shipped the brief's own 10 / 22 / 28, but a `ChamferPanel`
    // inside another drew the overlay twice -- measured at a 42.2% drop where
    // 22 was asked for -- so what was judged was never the figure. With the
    // stacking fixed they went to 8 / 15 / 19, and then to **4 / 8 / 10** on
    // the user's own reading of them at those figures. The vignette went with
    // them, 0.85 to 0.38 to **0.19**: it is atmosphere, and atmosphere that
    // announces itself is a filter.
    //
    // **A treatment is a named look, not a level.** `LIGHT` and `HEAVY` were a
    // dimmer switch on one effect; a rolling band and a vignette are not more
    // of the same thing, so the setting names looks and the EFFECTS page shows
    // each one rendered rather than described.
    readonly property var treatments: [
        {
            key: "NONE",
            name: "NONE",
            about: "No overlay at all. The reference.",
            pitch: 0,
            strength: 0,
            band: false,
            vignette: false
        },
        {
            key: "FINE_FAINT",
            name: "FINE FAINT",
            about: "A 1 px line every 3 px, at 4% black.",
            pitch: 3,
            strength: 0.04,
            band: false,
            vignette: false
        },
        {
            key: "FINE_STRONGER",
            name: "FINE STRONGER",
            about: "The same spacing, at 8%. The lines read as texture.",
            pitch: 3,
            strength: 0.08,
            band: false,
            vignette: false
        },
        {
            key: "WIDE",
            name: "WIDE",
            about: "A line every 4 px at 10%. Coarser, and darker with it.",
            pitch: 4,
            strength: 0.1,
            band: false,
            vignette: false
        },
        {
            key: "ROLLING",
            name: "FINE + ROLLING BAND",
            about: "Faint lines, and a soft bright band drifting down the screen every 7 s.",
            pitch: 3,
            strength: 0.04,
            band: true,
            vignette: false
        },
        {
            key: "CRT",
            name: "FULL CRT",
            about: "Lines at 8%, the band, and the screen's corners darkened.",
            pitch: 3,
            strength: 0.08,
            band: true,
            vignette: true
        }
    ]

    // The stored key.
    property string scanlines: "NONE"

    function treatmentFor(key: string): var {
        return root.treatments.find(entry => entry.key === key) ?? root.treatments[0];
    }

    // **Demo mode overrides rather than sets.** Taking a video should not
    // write the user's `effects.json`, twice, to turn the lines off and on
    // again. An empty override is the ordinary case.
    readonly property var treatment: root.treatmentFor(Demo.scanlines || root.scanlines)

    readonly property bool scanlinesOn: root.treatment.key !== "NONE"
    readonly property int scanlinePitch: root.treatment.pitch
    readonly property real scanlineOpacity: root.treatment.strength
    readonly property bool scanlineBand: root.treatment.band
    readonly property bool scanlineVignette: root.treatment.vignette

    // --- The rolling band's clock ---------------------------------------------
    // **One phase for the whole shell.** Every surface places the band from its
    // own position in the window against this, so a band crossing the screen
    // crosses the bar and the deck's panels as one band rather than as five
    // bands all starting at once.
    property real bandPhase: 0

    // **The clock runs only while something is drawing a band.** Each overlay
    // that wants one says so while it is visible, and the count is what keeps
    // this from writing a property sixty times a second for a shell whose
    // treatment has no band in it -- which is most of them, and was the state
    // the first version left it in while the EFFECTS page's own previews sat
    // frozen because the *setting* had no band.
    property int bandUsers: 0

    function holdBand(on: bool): void {
        root.bandUsers = Math.max(0, root.bandUsers + (on ? 1 : -1));
    }

    NumberAnimation on bandPhase {
        running: root.bandUsers > 0
        from: 0
        to: 1
        duration: 7000
        loops: Animation.Infinite
    }

    // --- Coverage --------------------------------------------------------------
    // PANELS or EVERYTHING. EVERYTHING adds the wallpaper surface.
    property string scanlinesOver: "PANELS"
    // Keeps the lines off anything that is not part of this shell: application
    // windows, video, the terminal's contents. On by default.
    property bool excludeWindowContent: true
    // Keeps them off a fullscreen window. **Forced on while
    // `excludeWindowContent` is**, because a fullscreen window is window
    // content and a checkbox that can only be true should say so.
    property bool excludeFullscreenSetting: true

    readonly property bool excludeFullscreen: excludeWindowContent || excludeFullscreenSetting
    readonly property bool fullscreenLocked: excludeWindowContent

    readonly property var coverageModes: ["PANELS", "EVERYTHING"]

    // Panels and the bar always take them when they are on; the wallpaper only
    // under EVERYTHING.
    readonly property bool scanlinesOnPanels: scanlinesOn
    readonly property bool scanlinesOnWallpaper: scanlinesOn && scanlinesOver === "EVERYTHING"
    // The only way a line can reach a window is a surface of our own drawn over
    // one, and that surface exists only when the exclusion is off.
    readonly property bool scanlinesOverWindows: scanlinesOn && !excludeWindowContent

    // --- Glitch ----------------------------------------------------------------
    // OFF, RARE, NORMAL or CUSTOM. The first three are presets that fill the
    // fields below; CUSTOM is what the row says once the numbers are the
    // user's own.
    property string glitch: "NORMAL"

    readonly property var glitchModes: ["OFF", "RARE", "NORMAL", "CUSTOM"]

    // **The interval, in whole seconds.** With `glitchRange` on a glitch fires
    // somewhere between `glitchFrom` and `glitchTo`, re-rolled every time, so
    // it is never metronomic. With it off it fires at exactly `glitchEvery`,
    // which *is* metronomic and is the point of offering it.
    property bool glitchRange: true
    property int glitchFrom: 30
    property int glitchTo: 90
    property int glitchEvery: 45

    readonly property int minSeconds: 2
    readonly property int maxSeconds: 3600

    // --- What a glitch is made of ---------------------------------------------
    // **The pool is never empty.** Turning the last effect off turns `SPLIT`
    // back on: a glitch with no effect in it is the schedule running for
    // nothing, and a control that can switch the feature off by a side door is
    // a control that will be used by accident.
    property var glitchEffects: ["SPLIT", "SLICE", "SCRAMBLE"]

    readonly property var allEffects: ["SPLIT", "SLICE", "SCRAMBLE"]

    // ONE, TWO (1-2), THREE (1-3) or WEIGHTED -- the design system's own
    // distribution, about 70% one, 24% two and 6% three, stacked on the same
    // element.
    property string glitchCount: "WEIGHTED"

    readonly property var countModes: ["ONE", "TWO", "THREE", "WEIGHTED"]
    readonly property var countLabels: ({
        ONE: "ONE",
        TWO: "1-2",
        THREE: "1-3",
        WEIGHTED: "WEIGHTED"
    })

    // How many elements may be glitching at once.
    property string glitchOverlap: "ONE"

    readonly property var overlapModes: ["ONE", "TWO", "ANY"]
    readonly property var overlapLabels: ({
        ONE: "ONE AT A TIME",
        TWO: "UP TO TWO",
        ANY: "ANY"
    })

    readonly property int overlapLimit: glitchOverlap === "ANY" ? 99 : glitchOverlap === "TWO" ? 2 : 1

    // Which areas of the shell may be picked from. **All four off is the same
    // as OFF**, and is allowed to be: it is a legible way of saying "not on
    // anything".
    property var glitchGroups: ["bar", "deck", "overlay", "lock"]

    readonly property var allGroups: ["bar", "deck", "overlay", "lock"]
    readonly property var groupLabels: ({
        bar: "BAR",
        deck: "DECK PANELS",
        overlay: "DROPDOWNS AND OVERLAYS",
        lock: "LOCKSCREEN"
    })

    function effectOn(name: string): bool {
        return root.glitchEffects.indexOf(name) >= 0;
    }

    function groupOn(name: string): bool {
        return root.glitchGroups.indexOf(name) >= 0;
    }

    function toggleEffect(name: string): void {
        if (root.allEffects.indexOf(name) < 0)
            return;
        const next = root.effectOn(name) ? root.glitchEffects.filter(e => e !== name) : root.glitchEffects.concat([name]);
        glitchEffects = next.length ? next : ["SPLIT"];
        write();
    }

    function toggleGroup(name: string): void {
        if (root.allGroups.indexOf(name) < 0)
            return;
        glitchGroups = root.groupOn(name) ? root.glitchGroups.filter(g => g !== name) : root.glitchGroups.concat([name]);
        write();
    }

    function setGlitchCount(mode: string): void {
        if (countModes.indexOf(mode) < 0)
            return;
        glitchCount = mode;
        write();
    }

    function setGlitchOverlap(mode: string): void {
        if (overlapModes.indexOf(mode) < 0)
            return;
        glitchOverlap = mode;
        write();
    }

    readonly property var glitchPresets: ({
        RARE: [60, 180],
        NORMAL: [30, 90]
    })

    // -1 for anything that is not a number, so a hand-edited `"abc"` leaves
    // the field where it was rather than silently becoming 2 seconds.
    function clampSeconds(value: int): int {
        const n = Number(value);
        if (!isFinite(n))
            return -1;
        return Math.max(root.minSeconds, Math.min(root.maxSeconds, Math.round(n)));
    }

    // The next interval, in milliseconds. Read fresh on every tick, so a change
    // lands on the next one without restarting anything.
    function nextInterval(): int {
        if (!root.glitchRange)
            return root.glitchEvery * 1000;
        const from = Math.min(root.glitchFrom, root.glitchTo);
        const to = Math.max(root.glitchFrom, root.glitchTo);
        return Math.round((from + Math.random() * (to - from)) * 1000);
    }

    // --- Setters ----------------------------------------------------------------
    // Each one validates, because the file is hand-editable and a typo in it
    // should leave the setting where it was rather than blank the shell's
    // atmosphere.
    function setGlitch(mode: string): void {
        if (glitchModes.indexOf(mode) < 0)
            return;
        glitch = mode;
        const preset = root.glitchPresets[mode];
        if (preset) {
            glitchRange = true;
            glitchFrom = preset[0];
            glitchTo = preset[1];
        }
        write();
    }

    // Any edit to a field is the user taking the numbers over, so the setting
    // moves to CUSTOM -- unless it is OFF, which is about whether the schedule
    // runs at all rather than how often.
    function claimCustom(): void {
        if (root.glitch !== "OFF")
            root.glitch = "CUSTOM";
    }

    function setGlitchRange(on: bool): void {
        glitchRange = on;
        claimCustom();
        write();
    }

    // **Committed as a pair, already validated.** The EFFECTS page checks the
    // whole set before calling these, because `FROM` and `TO` are only right
    // or wrong together and a field that clamps under the user's hands while
    // they are still typing is worse than one that says what is wrong. The
    // clamp stays as a floor for anything arriving from a hand-edited file.
    function commitRange(from: int, to: int): void {
        const a = root.clampSeconds(from);
        const b = root.clampSeconds(to);
        if (a < 0 || b < 0)
            return;
        glitchFrom = a;
        glitchTo = b;
        if (glitchFrom > glitchTo)
            glitchTo = glitchFrom;
        claimCustom();
        write();
    }

    function commitEvery(every: int): void {
        const n = root.clampSeconds(every);
        if (n < 0)
            return;
        glitchEvery = n;
        claimCustom();
        write();
    }

    function setScanlines(key: string): void {
        if (!root.treatments.some(entry => entry.key === key))
            return;
        if (Demo.active) {
            Demo.setScanlines(key);
            return;
        }
        scanlines = key;
        write();
    }

    function setScanlinesOver(mode: string): void {
        if (coverageModes.indexOf(mode) < 0)
            return;
        scanlinesOver = mode;
        write();
    }

    function setExcludeWindowContent(on: bool): void {
        excludeWindowContent = on;
        write();
    }

    function setExcludeFullscreen(on: bool): void {
        // Locked on while window content is excluded; the checkbox is greyed
        // there, and this is the same answer for anything else that asks.
        if (root.fullscreenLocked)
            return;
        excludeFullscreenSetting = on;
        write();
    }

    // --- Persistence --------------------------------------------------------
    // **Nothing writes before it has read.** A config reload rebuilds this
    // singleton with the defaults and the FileView loads asynchronously, so a
    // write in that window would persist `NORMAL` / `NONE` over whatever the
    // user had. A file we cannot read is not a file we may overwrite, so a
    // parse failure leaves the flag false as well.
    property bool loaded: false

    function write(): void {
        if (!root.loaded)
            return;
        file.setText(`${JSON.stringify({
            glitch: root.glitch,
            glitchRange: root.glitchRange,
            glitchFrom: root.glitchFrom,
            glitchTo: root.glitchTo,
            glitchEvery: root.glitchEvery,
            glitchEffects: root.glitchEffects,
            glitchCount: root.glitchCount,
            glitchOverlap: root.glitchOverlap,
            glitchGroups: root.glitchGroups,
            scanlines: root.scanlines,
            scanlinesOver: root.scanlinesOver,
            excludeWindowContent: root.excludeWindowContent,
            excludeFullscreen: root.excludeFullscreenSetting
        }, null, 2)}\n`);
    }

    // The keys batch 12 wrote, so a file from before this one still means
    // something rather than resetting the user's choice.
    readonly property var legacyScanlines: ({
        OFF: "NONE",
        LIGHT: "FINE_FAINT",
        HEAVY: "FINE_STRONGER"
    })

    function adopt(contents: string): void {
        // An empty file is a valid "nothing set yet", and it counts as read.
        if (!contents.trim()) {
            loaded = true;
            return;
        }
        try {
            const parsed = JSON.parse(contents);
            if (root.glitchModes.indexOf(parsed.glitch) >= 0)
                glitch = parsed.glitch;
            if (typeof parsed.glitchRange === "boolean")
                glitchRange = parsed.glitchRange;
            if (parsed.glitchFrom !== undefined && root.clampSeconds(parsed.glitchFrom) > 0)
                glitchFrom = root.clampSeconds(parsed.glitchFrom);
            if (parsed.glitchTo !== undefined && root.clampSeconds(parsed.glitchTo) > 0)
                glitchTo = root.clampSeconds(parsed.glitchTo);
            if (glitchFrom > glitchTo)
                glitchTo = glitchFrom;
            if (parsed.glitchEvery !== undefined && root.clampSeconds(parsed.glitchEvery) > 0)
                glitchEvery = root.clampSeconds(parsed.glitchEvery);
            if (Array.isArray(parsed.glitchEffects)) {
                const pool = parsed.glitchEffects.filter(e => root.allEffects.indexOf(e) >= 0);
                glitchEffects = pool.length ? pool : ["SPLIT"];
            }
            if (root.countModes.indexOf(parsed.glitchCount) >= 0)
                glitchCount = parsed.glitchCount;
            if (root.overlapModes.indexOf(parsed.glitchOverlap) >= 0)
                glitchOverlap = parsed.glitchOverlap;
            if (Array.isArray(parsed.glitchGroups))
                glitchGroups = parsed.glitchGroups.filter(g => root.allGroups.indexOf(g) >= 0);

            const key = root.legacyScanlines[parsed.scanlines] ?? parsed.scanlines;
            if (root.treatments.some(entry => entry.key === key))
                scanlines = key;
            if (root.coverageModes.indexOf(parsed.scanlinesOver) >= 0)
                scanlinesOver = parsed.scanlinesOver;
            if (typeof parsed.excludeWindowContent === "boolean")
                excludeWindowContent = parsed.excludeWindowContent;
            if (typeof parsed.excludeFullscreen === "boolean")
                excludeFullscreenSetting = parsed.excludeFullscreen;
            loaded = true;
        } catch (error) {
            console.warn(`wrayth: effects.json will not parse (${error}); leaving it alone`);
        }
    }

    FileView {
        id: file

        path: Paths.effectsFile
        watchChanges: true
        printErrors: false

        onLoaded: root.adopt(text())
        onFileChanged: reload()
        onLoadFailed: error => {
            // No file yet is the fresh install: the defaults stand, and the
            // first change the user makes writes them all down.
            if (error === FileViewError.FileNotFound)
                root.loaded = true;
        }
    }
}
