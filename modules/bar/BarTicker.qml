import QtQuick
import qs.components
import qs.config
import qs.services
import qs.utils

// The centre of the bar: live host status scrolling past, with the katakana tag
// pinned to its right. This is the only flexible element on the bar, so it takes
// up whatever the fixed side groups leave and absorbs any change in their width.
Item {
    id: root

    readonly property string line: {
        const segments = [
            SystemStatus.breach ? `ICE BREACH ${SystemStatus.failedUnits}` : "ICE NOMINAL",
            `${SystemStatus.failedUnits} FAILED UNITS`,
            `VULN ${Vuln.count} AFFECTED`,
            `PKG ${SystemStatus.pendingUpdates} PENDING`,
            `QUEUE ${Planner.done}/${Planner.total} CLEARED`,
            SystemStatus.ssid ? `UPLINK ${Demo.ssid(SystemStatus.ssid).toUpperCase()} ${SystemStatus.uplinkDown ? "DOWN" : `${Math.round(SystemStatus.pingMs)}MS`}` : "UPLINK OFFLINE",
            SystemStatus.shieldState === "armed" ? `SHIELD ${SystemStatus.shieldFirewall.toUpperCase()}`
                : SystemStatus.shieldState === "down" ? "SHIELD DOWN" : "SHIELD UNKNOWN",
            `PROFILE ${Theme.profile.toUpperCase()}`
        ];
        // While something plays, it leads the loop: its title, and who by.
        const track = Media.playing ? Media.players.find(p => p.isPlaying) : null;
        if (track && track.trackTitle)
            segments.unshift(`NOW PLAYING ${track.trackTitle.toUpperCase()}${track.trackArtist ? ` BY ${track.trackArtist.toUpperCase()}` : ""}`);
        // Leading and trailing separators so the loop reads continuously.
        return `// ${segments.join(" // ")} `;
    }

    // The same hairline that separates the readouts, closing off both ends of
    // the scroll. Without them the words fade in and out of nothing.
    Divider {
        id: leftRule

        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
    }

    // `dividerGap` of plain air off each rule, the same as the katakana takes
    // from its own. The marquee must not start fading at the hairline: a word
    // dissolving into the rule reads as the rule smearing, not as the line
    // scrolling away. So the air is real, and it is the *fade* that was cut to
    // keep the three gaps looking alike -- see `metrics.tickerFade`. Air plus a
    // ramp can never measure exactly the same as air alone; a short ramp is what
    // brings it close.
    Ticker {
        anchors.left: leftRule.right
        anchors.leftMargin: Appearance.metrics.dividerGap
        anchors.right: rightRule.left
        anchors.rightMargin: Appearance.metrics.dividerGap
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height

        text: root.line
    }

    Divider {
        id: rightRule

        anchors.right: katakana.left
        anchors.rightMargin: Appearance.metrics.dividerGap
        anchors.verticalCenter: parent.verticalCenter
    }

    KanaTag {
        id: katakana
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        text: "レイス"
        centreInk: true
    }
}
