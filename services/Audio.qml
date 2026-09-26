pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.services

// Audio: the default output and input, every output and input device, and
// every app currently producing sound. Shared by the bar's AUDIO readout and
// dropdown, the volume popup and the signal panel. All of it is PipeWire's
// own state, delivered as it changes -- nothing here polls.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false

    readonly property string deviceName: shortName(sink)

    // The short form a readout can hold: a headset's own name as it gives
    // it, and "SPEAKERS" / "MICROPHONE" for the machine's built-in card,
    // which describes itself as "Built-in Audio Analog Stereo".
    function shortName(node: var): string {
        const name = (node?.nickname || node?.description || node?.name || "").trim();
        if (!name)
            return "";
        const cls = node?.properties?.["media.class"] ?? "";
        if (/built.?in|analog|speaker/i.test(name))
            return cls.startsWith("Audio/Source") ? "MICROPHONE" : "SPEAKERS";
        return name.toUpperCase();
    }

    function mediaClass(node: var): string {
        return node?.properties?.["media.class"] ?? "";
    }

    readonly property var allNodes: Pipewire.nodes?.values ?? []

    // Hardware and virtual devices, in PipeWire's own (stable) order, by the
    // node type PipeWire reports up front -- a node's properties only arrive
    // once it is tracked, so they cannot decide what gets tracked.
    readonly property var outputs: allNodes.filter(n => n && n.type === PwNodeType.AudioSink).sort((a, b) => a.id - b.id)
    readonly property var inputs: allNodes.filter(n => n && n.type === PwNodeType.AudioSource).sort((a, b) => a.id - b.id)
    // Apps producing sound: playback streams, not capture ones.
    readonly property var streams: allNodes.filter(n => n && n.type === PwNodeType.AudioOutStream)

    // Streams carrying a call rather than media: PipeWire's `media.role`,
    // which voice apps (Discord, browsers in a call, softphones) set.
    function isCall(node: var): bool {
        const role = (node?.properties?.["media.role"] ?? "").toLowerCase();
        return role === "communication" || role === "phone";
    }
    readonly property var callStreams: streams.filter(n => isCall(n))

    function appName(node: var): string {
        const p = node?.properties ?? {};
        return (p["application.name"] || p["application.process.binary"] || node?.description || node?.name || "APP").trim();
    }

    // Anything the user could actually hear right now.
    readonly property bool audible: !muted && volume > 0

    // An external output -- bluetooth headphones, a USB interface -- as
    // against the machine's own card.
    readonly property bool external: {
        const name = sink?.name ?? "";
        return name !== "" && !/^alsa_output\.pci/i.test(name) && !/built.?in|analog|speaker/i.test(sink?.description ?? "");
    }

    // The signal panel's four states. The rules are taken in the order the
    // spec gives them, with STANDBY as the fallback.
    readonly property string state: {
        if (Cava.live)
            return audible ? "LIVE" : "MUTED";
        if (!external && !audible)
            return "OFFLINE";
        return "STANDBY";
    }

    // --- Actions --------------------------------------------------------------
    // Volumes are set in 5% steps, the same steps the keys and the meters use.
    function snap(value: real): real {
        return Math.max(0, Math.min(1, Math.round(value * 20) / 20));
    }

    function setVolume(node: var, value: real): void {
        if (node?.audio)
            node.audio.volume = snap(value);
    }

    function toggleMute(node: var): void {
        if (node?.audio)
            node.audio.muted = !node.audio.muted;
    }

    // **Cleared first, so every choice is written.** Quickshell only writes the
    // preference when its own copy changes -- so choosing a device a second
    // time did nothing if it was the last one chosen, even after the system
    // had moved away from it (a headset dropping and coming back, say).
    function useOutput(node: var): void {
        if (!node)
            return;
        Pipewire.preferredDefaultAudioSink = null;
        Pipewire.preferredDefaultAudioSink = node;
    }

    function useInput(node: var): void {
        if (!node)
            return;
        Pipewire.preferredDefaultAudioSource = null;
        Pipewire.preferredDefaultAudioSource = node;
    }

    // Super + Shift + A: the next output, wrapping. The volume popup names it
    // (see Osd).
    function cycleOutput(): string {
        if (outputs.length === 0)
            return "none";
        const at = outputs.findIndex(n => n === sink);
        const next = outputs[(at + 1) % outputs.length];
        useOutput(next);
        return shortName(next);
    }

    // Without this the nodes' volume and mute stay at their defaults.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(n => n).concat(root.outputs).concat(root.inputs).concat(root.streams)
    }
}
