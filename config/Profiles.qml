pragma Singleton

import QtQuick
import Quickshell
import qs.config

// Palette data for the six presets, merged with whatever custom profiles the
// user has made. Theme picks one and exposes its tokens to the rest of the
// shell; nothing downstream knows or cares which kind it got.
Singleton {
    id: root

    readonly property list<string> presetNames: ["Circuit", "Sodium", "Prism", "Redline", "Oxide", "Cobalt"]

    // Presets first, then customs in creation order. The picker's cards, the
    // launcher's profile entries and `profile list` all read this order.
    readonly property var names: root.presetNames.concat(Customs.names)

    function isCustom(name: string): bool {
        return Customs.has(name);
    }

    // --- Deriving the rest of a palette --------------------------------------
    // A custom profile authors nine colours; these are the other seven. Every
    // figure here was measured across the six presets rather than chosen, and
    // reproduces them to within 3/255 -- except `mute`, where the presets
    // themselves disagree (the blend runs from 0.47 in Circuit to 0.66 in
    // Redline) and 0.56 is the factor with the smallest worst case, 9/255 on
    // Redline. `mute` colours inactive markers, so that is the right place for
    // the slack to land.
    //
    // The three translucent fills and `barBg` are struck off the authored
    // PANEL rather than off GROUND, so a user who picks a panel colour gets
    // panels in it. In the presets the two are close but not equal.
    function derive(nine: var): var {
        const panelHex = nine.panel;
        return {
            ground: nine.ground,
            deep: root.darken(nine.ground, 6),
            panelHex: panelHex,
            panel: root.translucent(root.scale(panelHex, 0.63), 0.8),
            panel2: root.translucent(root.scale(panelHex, 0.85), 0.82),
            barBg: root.translucent(root.scale(panelHex, 0.54), 0.92),
            hair: nine.hair,
            text: nine.text,
            bright: nine.bright,
            dim: nine.dim,
            mute: root.mix(nine.dim, nine.hair, 0.56),
            track: root.mix(nine.ground, nine.hair, 0.6),
            cell: root.translucent(nine.hair, 0.35),
            signal: nine.signal,
            accent: nine.accent,
            alert: nine.alert
        };
    }

    // The nine authored colours of any profile, custom or preset. A preset has
    // no such record -- it is a whole palette -- so its nine are read back out
    // of it, which is what makes `START FROM` a copy rather than a link.
    function nineOf(name: string): var {
        const custom = Customs.find(name);
        if (custom)
            return Object.assign({}, custom.colors);
        const preset = root.presets[name] ?? root.presets.Circuit;
        const nine = {};
        for (const entry of Customs.roles)
            nine[entry.key] = String(entry.key === "panel" ? preset.panelHex : preset[entry.key]);
        return nine;
    }

    // --- Colour arithmetic ---------------------------------------------------
    // These take and return `#RRGGBB` strings rather than `color`s, because a
    // custom palette is stored as hex and a hand edit of the file has to read
    // as the same thing the editor wrote.
    // Accepts `#rrggbb` and the `#aarrggbb` a QML `color` stringifies to, so a
    // token read back off a live palette parses the same as one read off disk.
    function rgbOf(hex: string): var {
        let t = String(hex).replace("#", "");
        if (t.length === 8)
            t = t.slice(2);
        return [parseInt(t.slice(0, 2), 16), parseInt(t.slice(2, 4), 16), parseInt(t.slice(4, 6), 16)];
    }

    function hexOf(rgb: var): string {
        return "#" + rgb.map(v => Math.max(0, Math.min(255, Math.round(v))).toString(16).padStart(2, "0")).join("");
    }

    function scale(hex: string, factor: real): string {
        return root.hexOf(root.rgbOf(hex).map(v => v * factor));
    }

    function darken(hex: string, amount: int): string {
        return root.hexOf(root.rgbOf(hex).map(v => v - amount));
    }

    function mix(a: string, b: string, t: real): string {
        const x = root.rgbOf(a);
        const y = root.rgbOf(b);
        return root.hexOf([0, 1, 2].map(i => x[i] + (y[i] - x[i]) * t));
    }

    function translucent(hex: string, a: real): color {
        const c = root.rgbOf(hex);
        return Qt.rgba(c[0] / 255, c[1] / 255, c[2] / 255, a);
    }

    // Relative luminance and the WCAG contrast ratio, for the editor's
    // readout. Both take hex, like everything else here.
    function luminance(hex: string): real {
        const channel = v => {
            const s = v / 255;
            return s <= 0.03928 ? s / 12.92 : Math.pow((s + 0.055) / 1.055, 2.4);
        };
        const c = root.rgbOf(hex).map(channel);
        return 0.2126 * c[0] + 0.7152 * c[1] + 0.0722 * c[2];
    }

    function contrast(a: string, b: string): real {
        const la = root.luminance(a);
        const lb = root.luminance(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // --- The palettes --------------------------------------------------------
    readonly property var palettes: {
        const merged = {};
        for (const name of root.presetNames)
            merged[name] = root.presets[name];
        for (const entry of Customs.list)
            merged[entry.name] = root.derive(entry.colors);
        return merged;
    }

    readonly property var presets: ({
        Circuit: {
            ground: "#0B0D10",
            deep: "#05070A",
            panelHex: "#0F1318",
            panel: Qt.rgba(9 / 255, 11 / 255, 14 / 255, 0.8),
            panel2: Qt.rgba(12 / 255, 15 / 255, 19 / 255, 0.82),
            barBg: Qt.rgba(8 / 255, 10 / 255, 13 / 255, 0.92),
            hair: "#2A323C",
            text: "#C9D1D9",
            bright: "#E6EDF3",
            dim: "#7D8894",
            mute: "#56606B",
            track: "#1E252D",
            cell: Qt.rgba(42 / 255, 50 / 255, 60 / 255, 0.35),
            signal: "#4FC3C9",
            accent: "#FF3B45",
            alert: "#E8E03A"
        },
        Sodium: {
            ground: "#0C0C0A",
            deep: "#070706",
            panelHex: "#121210",
            panel: Qt.rgba(12 / 255, 12 / 255, 10 / 255, 0.8),
            panel2: Qt.rgba(16 / 255, 16 / 255, 13 / 255, 0.82),
            barBg: Qt.rgba(10 / 255, 10 / 255, 8 / 255, 0.92),
            hair: "#2E2D27",
            text: "#D6D3C8",
            bright: "#F2EFE4",
            dim: "#8A877B",
            mute: "#5A5850",
            track: "#22211C",
            cell: Qt.rgba(46 / 255, 45 / 255, 39 / 255, 0.35),
            signal: "#36D6E7",
            accent: "#F2E94E",
            alert: "#FF3B45"
        },
        Prism: {
            ground: "#0B0913",
            deep: "#06040C",
            panelHex: "#110E1C",
            panel: Qt.rgba(11 / 255, 9 / 255, 19 / 255, 0.8),
            panel2: Qt.rgba(15 / 255, 12 / 255, 26 / 255, 0.82),
            barBg: Qt.rgba(9 / 255, 7 / 255, 16 / 255, 0.92),
            hair: "#2E2640",
            text: "#D4CFE6",
            bright: "#F0ECFA",
            dim: "#8A83A3",
            mute: "#5A5470",
            track: "#1E1830",
            cell: Qt.rgba(46 / 255, 38 / 255, 64 / 255, 0.35),
            signal: "#3FD7FF",
            accent: "#FF2E88",
            alert: "#FFE066"
        },
        Redline: {
            ground: "#060606",
            deep: "#000000",
            panelHex: "#0C0D0E",
            panel: Qt.rgba(6 / 255, 6 / 255, 7 / 255, 0.82),
            panel2: Qt.rgba(10 / 255, 10 / 255, 11 / 255, 0.84),
            barBg: Qt.rgba(4 / 255, 4 / 255, 5 / 255, 0.94),
            hair: "#2B2E32",
            text: "#E2E3E5",
            bright: "#F7F7F8",
            dim: "#878C92",
            mute: "#4A4E53",
            track: "#1B1D20",
            cell: Qt.rgba(43 / 255, 46 / 255, 50 / 255, 0.4),
            signal: "#9EA7B0",
            accent: "#FF1A1A",
            alert: "#FFC23D"
        },
        Oxide: {
            ground: "#0D0A07",
            deep: "#070504",
            panelHex: "#14100B",
            panel: Qt.rgba(13 / 255, 10 / 255, 7 / 255, 0.8),
            panel2: Qt.rgba(18 / 255, 14 / 255, 10 / 255, 0.82),
            barBg: Qt.rgba(11 / 255, 8 / 255, 6 / 255, 0.92),
            hair: "#33291F",
            text: "#D9CDBE",
            bright: "#F4EADC",
            dim: "#8C7E6E",
            mute: "#5A4E41",
            track: "#231B14",
            cell: Qt.rgba(51 / 255, 41 / 255, 31 / 255, 0.35),
            signal: "#5FB3A8",
            accent: "#FF9F1C",
            alert: "#FF4B3E"
        },
        Cobalt: {
            ground: "#080B10",
            deep: "#04060A",
            panelHex: "#0D121A",
            panel: Qt.rgba(8 / 255, 11 / 255, 16 / 255, 0.8),
            panel2: Qt.rgba(11 / 255, 15 / 255, 22 / 255, 0.82),
            barBg: Qt.rgba(6 / 255, 9 / 255, 13 / 255, 0.92),
            hair: "#243042",
            text: "#D3DBE6",
            bright: "#F2F6FB",
            dim: "#8390A2",
            mute: "#4C5869",
            track: "#18202C",
            cell: Qt.rgba(36 / 255, 48 / 255, 66 / 255, 0.35),
            signal: "#A9B8C8",
            accent: "#3D8BFF",
            alert: "#FF4D4D"
        }
    })

    // Vibe lines, shown one per card in the profile picker. A custom profile
    // has no line of its own -- the editor never asks for one, because a
    // sentence is not a colour -- so it is given one built from what it *is*,
    // in the same shape as the presets': accent for action, signal for data.
    readonly property var descriptions: {
        const all = {};
        for (const name of root.presetNames)
            all[name] = root.presetDescriptions[name];
        for (const entry of Customs.list)
            all[entry.name] = `Custom palette. ${entry.colors.accent.toUpperCase()} for action, ${entry.colors.signal.toUpperCase()} for data.`;
        return all;
    }

    readonly property var presetDescriptions: ({
        Circuit: "Balanced default. Red for action, teal for data.",
        Sodium: "Streetlight yellow on warm grime. Loud and scrappy.",
        Prism: "Magenta and cyan on violet-black. The brightest palette.",
        Redline: "Chrome and red optics on black. Industrial and hostile.",
        Oxide: "Rust and amber on scorched brown. Road-worn.",
        Cobalt: "Cold blue on midnight steel. Clean and expensive."
    })

    // Case-insensitive lookup, so `wrayth-profile redline` works.
    function resolve(name: string): string {
        if (!name)
            return "";
        const wanted = name.trim().toLowerCase();
        for (const candidate of names) {
            if (candidate.toLowerCase() === wanted)
                return candidate;
        }
        return "";
    }
}
