pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// WEATHER, a daemon: off until added in the daemon library, and then only
// for a city you type -- the machine is never located. Looked up with
// Open-Meteo (open-meteo.com), which needs no account and no key: the city's
// name goes to its geocoding API once, then its coordinates to the forecast
// API every 30 minutes. Nothing else is sent. Settings live in
// ~/.config/wrayth/weather.json.
Singleton {
    id: root

    readonly property string file: `${Quickshell.env("HOME")}/.config/wrayth/weather.json`

    property string city: ""          // as Open-Meteo names it
    property real lat: 0
    property real lon: 0
    property string unit: "c"         // c | f
    property bool ticker: false

    property var current: null        // { temp, code }
    property var hours: []            // [{ time, temp, code }], the next 12
    property string error: ""
    property bool busy: false
    property real fetchedAt: 0

    readonly property bool enabled: Daemons.isSelected("weather")
    readonly property bool located: city !== ""

    // WMO weather codes, in words.
    function condition(code: int): string {
        if (code === 0) return "CLEAR";
        if (code <= 2) return "PARTLY CLOUDY";
        if (code === 3) return "OVERCAST";
        if (code <= 48) return "FOG";
        if (code <= 57) return "DRIZZLE";
        if (code <= 67) return "RAIN";
        if (code <= 77) return "SNOW";
        if (code <= 82) return "SHOWERS";
        if (code <= 86) return "SNOW SHOWERS";
        return "THUNDERSTORM";
    }
    function temp(t: real): string {
        return `${Math.round(t)}°${unit === "f" ? "F" : "C"}`;
    }
    // CITY TEMP CONDITION: the row, and the ticker entry.
    readonly property string line: current ? `${city.toUpperCase()} ${temp(current.temp)} ${condition(current.code)}` : ""

    // --- Setting the city ------------------------------------------------------
    function setCity(name: string): void {
        const q = name.trim();
        if (q === "" || geo.running)
            return;
        error = "";
        busy = true;
        geo.command = ["curl", "-fsS", "--max-time", "10", "-G", "https://geocoding-api.open-meteo.com/v1/search", "--data-urlencode", `name=${q}`, "-d", "count=1", "-d", "format=json"];
        geo.running = true;
    }
    Process {
        id: geo
        stdout: StdioCollector {
            onStreamFinished: {
                root.busy = false;
                let r = null;
                try {
                    r = (JSON.parse(text).results ?? [])[0] ?? null;
                } catch (e) {}
                if (!r) {
                    root.error = "NO CITY BY THAT NAME";
                    return;
                }
                root.city = r.name;
                root.lat = r.latitude;
                root.lon = r.longitude;
                root.save();
                root.refresh();
            }
        }
        onExited: code => {
            if (code !== 0) {
                root.busy = false;
                root.error = "COULD NOT REACH OPEN-METEO";
            }
        }
    }
    // Forgets the city (and its readings); the file goes with it.
    function forget(): void {
        city = "";
        lat = 0;
        lon = 0;
        current = null;
        hours = [];
        remover.exec(["rm", "-f", "--", file]);
    }
    Process {
        id: remover
    }
    function setUnit(u: string): void {
        unit = u === "f" ? "f" : "c";
        save();
        refresh();
    }
    function setTicker(on: bool): void {
        ticker = on;
        save();
    }

    // --- The forecast ------------------------------------------------------------
    function refresh(): void {
        if (!enabled || !located || forecast.running)
            return;
        forecast.command = ["curl", "-fsS", "--max-time", "10", "-G", "https://api.open-meteo.com/v1/forecast",
            "-d", `latitude=${lat}`, "-d", `longitude=${lon}`,
            "-d", "current=temperature_2m,weather_code", "-d", "hourly=temperature_2m,weather_code",
            "-d", "forecast_hours=12", "-d", "timezone=auto", "-d", `temperature_unit=${unit === "f" ? "fahrenheit" : "celsius"}`];
        forecast.running = true;
    }
    Process {
        id: forecast
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    root.current = { temp: d.current.temperature_2m, code: d.current.weather_code };
                    const h = d.hourly;
                    root.hours = h.time.map((t, i) => ({ time: t.slice(11, 16), temp: h.temperature_2m[i], code: h.weather_code[i] })).slice(0, 12);
                    root.error = "";
                    root.fetchedAt = Date.now();
                    Daemons.setReading("weather", root.line, "signal");
                } catch (e) {
                    root.error = "OPEN-METEO ANSWERED WITH SOMETHING UNEXPECTED";
                }
            }
        }
        onExited: code => {
            if (code !== 0)
                root.error = "COULD NOT REACH OPEN-METEO";
        }
    }
    // Every 30 minutes, and only while the daemon is added and has a city.
    Timer {
        interval: 30 * 60 * 1000
        running: root.enabled && root.located
        repeat: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    // --- Settings --------------------------------------------------------------
    property bool loaded: false
    function save(): void {
        writer.setText(JSON.stringify({ city: city, lat: lat, lon: lon, unit: unit, ticker: ticker }, null, 2) + "\n");
    }
    FileView {
        id: writer
        path: root.file
        printErrors: false
    }
    FileView {
        path: root.file
        printErrors: false
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.city = s.city ?? "";
                root.lat = s.lat ?? 0;
                root.lon = s.lon ?? 0;
                root.unit = s.unit === "f" ? "f" : "c";
                root.ticker = !!s.ticker;
            } catch (e) {}
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }
}
