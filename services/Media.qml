pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import qs.services

// Every current audio source, for the deck's SIGNAL panel: media players
// (MPRIS) and calls (apps with a communication audio stream, such as a
// Discord call). One is selected -- by the chips in the panel, or on its own
// whatever starts playing -- and the spectrum follows only that one: cava is
// pointed at the PipeWire stream behind it (see Cava).
//
// Calls are shown, never controlled: mute, deafen and leave belong to the app.
// A system-level mute the app did not know about would leave someone muted
// without realising it.
Singleton {
    id: root

    readonly property var players: (Mpris.players?.values ?? []).filter(p => p && p.identity !== undefined)

    // A source: { key, kind: "media" | "call", player | node, app }.
    readonly property var sources: {
        const out = [];
        for (const p of players)
            out.push({ key: `media:${p.dbusName}`, kind: "media", player: p, node: null, app: root.appOf(p) });
        for (const n of Audio.callStreams)
            out.push({ key: `call:${n.id}`, kind: "call", player: null, node: n, app: Audio.appName(n) });
        return out;
    }

    // **What a source is called on its chip: the site, then the app.** For a
    // browser the website -- YOUTUBE, COURSERA, TWITCH -- from the media's own
    // URL, else its artwork's host, else a " - Site" suffix on the title;
    // for anything else, the app's name. Never BROWSER or FIREFOX when the
    // site can be known.
    readonly property var browsers: ["firefox", "zen", "chromium", "chrome", "google-chrome", "brave", "vivaldi", "librewolf", "edge", "opera", "floorp", "waterfox"]
    readonly property var cdnSites: ({ ytimg: "YOUTUBE", googlevideo: "YOUTUBE", jtvnw: "TWITCH", twitchcdn: "TWITCH", scdn: "SPOTIFY", sndcdn: "SOUNDCLOUD", vimeocdn: "VIMEO", nflxext: "NETFLIX", nflximg: "NETFLIX" })
    function siteOfUrl(url: string): string {
        const m = /^[a-z]+:\/\/([^/:?#]+)/i.exec(url || "");
        if (!m)
            return "";
        const labels = m[1].toLowerCase().replace(/^www\./, "").split(".").filter(l => l);
        if (labels.length === 0)
            return "";
        // The name before the domain ending (co.uk-style endings included).
        let i = labels.length >= 2 ? labels.length - 2 : 0;
        if (labels.length >= 3 && labels[i].length <= 3 && labels[labels.length - 1].length === 2)
            i -= 1;
        const name = labels[Math.max(0, i)];
        return (root.cdnSites[name] ?? name).toUpperCase();
    }
    function labelOf(source: var): string {
        if (!source)
            return "";
        if (source.kind === "call")
            return source.app.toUpperCase();
        const p = source.player;
        const app = root.appOf(p);
        const isBrowser = root.browsers.some(b => `${p?.identity ?? ""} ${p?.desktopEntry ?? ""} ${p?.dbusName ?? ""}`.toLowerCase().includes(b));
        if (isBrowser) {
            const md = p?.metadata ?? {};
            const site = root.siteOfUrl(String(md["xesam:url"] ?? "")) || root.siteOfUrl(String(p?.trackArtUrl ?? md["mpris:artUrl"] ?? ""));
            if (site && site !== "FILE" && site !== "LOCALHOST")
                return site;
            const t = /\s[-–|]\s([A-Za-z][A-Za-z0-9 .]{1,24})$/.exec(p?.trackTitle ?? "");
            if (t)
                return t[1].trim().toUpperCase();
        }
        return app.toUpperCase();
    }

    function appOf(player: var): string {
        return (player?.identity || player?.desktopEntry || "PLAYER").trim();
    }

    // The chosen source's key. Empty: not chosen yet, so the automatic pick
    // below applies.
    property string chosen: ""

    // Whatever is playing, else a call, else the first player.
    readonly property var automatic: sources.find(s => s.kind === "media" && s.player.isPlaying)
        ?? sources.find(s => s.kind === "call") ?? sources[0] ?? null

    readonly property var current: sources.find(s => s.key === chosen) ?? automatic

    function select(key: string): void {
        chosen = key;
    }

    // **The panel starts on whatever is playing.** A player that starts is
    // taken to be what the person wants to see, unless they have picked
    // something themselves since it last started.
    Variants {
        model: root.players

        Connections {
            required property var modelData

            target: modelData
            function onIsPlayingChanged(): void {
                if (modelData.isPlaying)
                    root.chosen = `media:${modelData.dbusName}`;
            }
        }
    }

    readonly property bool playing: players.some(p => p.isPlaying)
    // The player the media keys drive: the selected one if it is a player,
    // else whatever is playing, else the first.
    readonly property var player: current?.kind === "media" ? current.player : (players.find(p => p.isPlaying) ?? players[0] ?? null)

    // --- The stream behind a source, for the spectrum ----------------------
    // A player is matched to the PipeWire stream it plays through by the app
    // names both report; a call is its own stream. No match: "auto", every
    // sound at once, which is what the panel always showed before.
    function streamFor(source: var): var {
        if (!source)
            return null;
        if (source.kind === "call")
            return source.node;
        const want = [source.player.identity, source.player.desktopEntry, (source.player.dbusName ?? "").replace(/^org\.mpris\.MediaPlayer2\./, "").split(".")[0]]
            .filter(w => w).map(w => w.toLowerCase());
        const matches = Audio.streams.filter(n => {
            const p = n.properties ?? {};
            const have = [p["application.name"], p["application.process.binary"], p["application.id"], p["node.name"]]
                .filter(h => h).map(h => String(h).toLowerCase());
            return have.some(h => want.some(w => h === w || h.startsWith(w) || w.startsWith(h)));
        });
        // **Only an unambiguous match.** A browser has a stream per tab (and
        // keeps idle ones about), all under the one app name, and MPRIS does
        // not say which tab is playing -- taking the first match is what left
        // a Coursera video's spectrum flat while YouTube in the same browser
        // worked. Several candidates: the whole output instead.
        return matches.length === 1 ? matches[0] : null;
    }

    readonly property var stream: streamFor(current)
    // A source whose stream stayed silent while its player said it was
    // playing: some streams cannot be captured on their own. Those fall back
    // to the whole output for as long as the stream lasts (Cava.qml decides).
    property var silentStreams: ({})
    // cava's `source`: the stream's PipeWire object serial, or "auto".
    readonly property string cavaSource: {
        const serial = stream?.properties?.["object.serial"];
        if (serial === undefined || !/^\d+$/.test(String(serial)) || silentStreams[String(serial)])
            return "auto";
        return String(serial);
    }

    // --- Calls: how long each has been going --------------------------------
    property var callStarts: ({})
    onSourcesChanged: {
        const next = {};
        const now = Date.now();
        for (const s of sources)
            if (s.kind === "call")
                next[s.key] = callStarts[s.key] ?? now;
        callStarts = next;
    }

    // The window of the app a call is in, focused (OPEN CALL): matched by the
    // stream's process id, else by its app name against window classes.
    function openCall(source: var): void {
        if (!source || source.kind !== "call")
            return;
        const p = source.node?.properties ?? {};
        const pid = Number(p["application.process.id"] ?? 0);
        const app = String(p["application.name"] ?? "").toLowerCase().replace(/[^a-z0-9]/g, "");
        Deck.leave();
        Hyprland.dispatch(`(function() for _, w in ipairs(hl.get_windows()) do if (${pid} > 0 and w.pid == ${pid}) or ("${app}" ~= "" and (string.lower(w.class or ""):gsub("[^a-z0-9]", "")) == "${app}") then return hl.dsp.focus({ window = w }) end end return hl.dsp.no_op() end)()`);
    }

    // --- The media keys ----------------------------------------------------
    function toggle(): string {
        if (!player)
            return "none";
        player.togglePlaying();
        Osd.flash("media");
        return appOf(player);
    }
    function next(): string {
        if (!player || !player.canGoNext)
            return "none";
        player.next();
        Osd.flash("media");
        return appOf(player);
    }
    function previous(): string {
        if (!player || !player.canGoPrevious)
            return "none";
        player.previous();
        Osd.flash("media");
        return appOf(player);
    }
}
