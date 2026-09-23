pragma Singleton

import QtQuick
import Quickshell

// Shared number and string formatting. Everything here returns single-line text
// -- the spec never wraps.
Singleton {
    id: root

    // Byte rate -> the bar's compact "12K" / "1.4M" form.
    function rate(bytesPerSecond: real): string {
        const kib = bytesPerSecond / 1024;
        if (kib < 1000)
            return `${Math.round(kib)}K`;
        return `${(kib / 1024).toFixed(1)}M`;
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

    // The lockscreen's date line, e.g. "FRIDAY // 09.18.26".
    function lockDate(date: date): string {
        const days = ["SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY"];
        return `${days[date.getDay()]} // ${pad2(date.getMonth() + 1)}.${pad2(date.getDate())}.${pad2(date.getFullYear() % 100)}`;
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
}
