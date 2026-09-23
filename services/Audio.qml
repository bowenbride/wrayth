pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs.services

// The default sink: its name, level and mute state. Shared by the signal
// panel's header and the volume popup.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    readonly property string deviceName: {
        const name = (sink?.description || sink?.name || "").trim();
        if (!name)
            return "";
        // The spec asks for the short form -- a headset's model name or "SPEAKERS" -- and
        // a bluetooth sink's description already is one. The built-in card
        // describes itself as "Built-in Audio Analog Stereo", which is not.
        if (/built.?in|analog|speaker/i.test(name))
            return "SPEAKERS";
        return name.toUpperCase();
    }

    // Anything the user could actually hear right now.
    readonly property bool audible: !muted && volume > 0

    // An external output -- bluetooth headphones, a USB interface -- as
    // against the machine's own card. The built-in analog card is the one
    // thing on the PCI bus here.
    readonly property bool external: {
        const name = sink?.name ?? "";
        return name !== "" && !/^alsa_output\.pci/i.test(name);
    }

    // The signal panel's four states. The rules are taken in the order the
    // spec gives them, with STANDBY as the fallback, because the four do not
    // otherwise partition every combination -- an external device that is
    // muted with nothing playing is none of the other three.
    readonly property string state: {
        if (Cava.live)
            return audible ? "LIVE" : "MUTED";
        if (!external && !audible)
            return "OFFLINE";
        return "STANDBY";
    }

    // Without this the sink's volume and mute stay at their defaults.
    PwObjectTracker {
        objects: root.sink ? [root.sink] : []
    }
}
