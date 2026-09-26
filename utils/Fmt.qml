pragma Singleton

import QtQuick
import Quickshell

// Shared number and string formatting. Everything here returns single-line text
// -- the spec never wraps.
Singleton {
    id: root

    // Byte rate -> the bar's compact "12K" / "1.4M" form.
    // Byte rate -> at most four characters, the unit scaling (DESIGN.md):
    // 0K to 999K, then 1.0M to 9.9M and 10M to 99M, then 0.1G upward (1.0G
    // at a gibibyte a second). Never longer, so the bar's slot stays tight.
    function rate(bytesPerSecond: real): string {
        const kib = Math.max(0, bytesPerSecond) / 1024;
        if (Math.round(kib) < 1000)
            return `${Math.round(kib)}K`;
        const mib = kib / 1024;
        if (Number(mib.toFixed(1)) < 10)
            return `${Math.max(1, mib).toFixed(1)}M`;
        if (Math.round(mib) < 100)
            return `${Math.round(mib)}M`;
        const gib = mib / 1024;
        return Number(gib.toFixed(1)) < 10 ? `${gib.toFixed(1)}G` : `${Math.min(999, Math.round(gib))}G`;
    }

    // Byte rate -> the HUD's "12.4 KB/s" form.
    function rateLong(bytesPerSecond: real): string {
        const kib = bytesPerSecond / 1024;
        if (kib < 1000)
            return `${kib.toFixed(1)} KB/s`;
        return `${(kib / 1024).toFixed(2)} MB/s`;
    }

    function gib(value: real, decimals: int): string {
        return value.toFixed(decimals === undefined ? 1 : decimals);
    }

    function percent(value: real): string {
        return `${Math.round(value)}%`;
    }

    function pad2(value: int): string {
        return value < 10 ? `0${value}` : `${value}`;
    }

    // A long date line, e.g. "FRIDAY · 09.18.26".
    function lockDate(date: date): string {
        const days = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"];
        return `${days[date.getDay()]} · ${pad2(date.getMonth() + 1)}.${pad2(date.getDate())}.${pad2(date.getFullYear() % 100)}`;
    }

    // MM.DD.YY, e.g. "09.21.26". The lockscreen draws the numeric date and the
    // abbreviated day in different colours, so they are two calls rather than
    // one string -- matching the bar's `barDate` format without its ` // `.
    function dateNumeric(date: date): string {
        return `${pad2(date.getMonth() + 1)}.${pad2(date.getDate())}.${pad2(date.getFullYear() % 100)}`;
    }

    function dayAbbr(date: date): string {
        const days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
        return days[date.getDay()];
    }

    // MM.DD.YY DDD, e.g. "09.18.26 FRI"
    function barDate(date: date): string {
        const days = ["SUN", "MON", "TUE", "WED", "THU", "FRI", "SAT"];
        return `${pad2(date.getMonth() + 1)}.${pad2(date.getDate())}.${pad2(date.getFullYear() % 100)} ${days[date.getDay()]}`;
    }

    function clock(date: date): string {
        return `${pad2(date.getHours())}:${pad2(date.getMinutes())}:${pad2(date.getSeconds())}`;
    }

    // The bar draws the seconds separately, as a raised accent superscript.
    function clockHM(date: date): string {
        return `${pad2(date.getHours())}:${pad2(date.getMinutes())}`;
    }

    // <d>D HH:MM:SS, as the power menu writes uptime.
    function uptime(seconds: real): string {
        const total = Math.floor(seconds);
        const rest = total % 86400;
        return `${Math.floor(total / 86400)}D ${pad2(Math.floor(rest / 3600))}:${pad2(Math.floor(rest / 60) % 60)}:${pad2(rest % 60)}`;
    }

    // HH:MM:SS with hours allowed past 24, for uptime.
    function duration(seconds: real): string {
        const total = Math.floor(seconds);
        return `${pad2(Math.floor(total / 3600))}:${pad2(Math.floor(total / 60) % 60)}:${pad2(total % 60)}`;
    }

    // How long ago, in the shell's short form: NOW under a minute, then 4M,
    // 2H, 3D. For lists that say when something arrived.
    function age(ms: real, now: real): string {
        const s = Math.max(0, Math.floor((now - ms) / 1000));
        if (s < 60)
            return "NOW";
        if (s < 3600)
            return `${Math.floor(s / 60)}M`;
        if (s < 86400)
            return `${Math.floor(s / 3600)}H`;
        return `${Math.floor(s / 86400)}D`;
    }
}
