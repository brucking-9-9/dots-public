pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Night mode = wl-gammarelay-rs (temperature over DBus) + the night-schedule
// script from quickshell-bottom.nix. Must tolerate both being absent (live
// `-p` runs before the first switch): show "--" and back off, never spam.
Singleton {
    id: root

    property int temperature: 0        // 0 = unknown / daemon absent
    property string phase: ""          // day | dusk | night (from the script, or computed)
    property string mode: ""           // auto | manual ("" = script absent)
    readonly property bool daemonOk: temperature > 0
    readonly property string label: daemonOk ? temperature + "K" : "--"
    readonly property string currentPhase: phase !== "" ? phase : localPhase()

    readonly property int minK: 2500
    readonly property int maxK: 6500

    // live temperature stream
    Process {
        id: watch
        command: ["wl-gammarelay-rs", "watch", "{t}"]
        running: true
        stdout: SplitParser {
            onRead: data => {
                const n = parseInt(data.trim());
                if (!isNaN(n)) root.temperature = n;
            }
        }
        onExited: {
            root.temperature = 0;
            retry.start();
        }
    }
    Timer {
        id: retry
        interval: 60000
        onTriggered: watch.running = true
    }

    // schedule state: "<K> <phase> <auto|manual>"
    Process {
        id: status
        command: ["night-schedule", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/);
                if (p.length >= 3) {
                    root.phase = p[1];
                    root.mode = p[2];
                }
            }
        }
        onExited: code => {
            if (code !== 0) {
                root.phase = "";
                root.mode = "";
                statusTimer.interval = 300000;   // script missing: poll every 5 min
            } else {
                statusTimer.interval = 60000;
            }
        }
    }
    Timer {
        id: statusTimer
        interval: 60000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: status.running = true
    }
    Timer {
        id: refreshSoon
        interval: 500
        onTriggered: status.running = true
    }

    function clampK(k) {
        return Math.min(maxK, Math.max(minK, Math.round(k / 100) * 100));
    }

    // Prefer the script (it records the manual marker); fall back to a bare
    // DBus write so the slider works in a live run before the first switch.
    function setManual(k) {
        k = clampK(k);
        Quickshell.execDetached(["sh", "-c",
            'night-schedule set "$1" 2>/dev/null || busctl --user set-property rs.wl-gammarelay / rs.wl.gammarelay Temperature q "$1"',
            "sh", String(k)]);
        refreshSoon.restart();
    }

    function auto() {
        Quickshell.execDetached(["night-schedule", "auto"]);
        refreshSoon.restart();
    }

    // Same piecewise phase logic as the script, for the label when it is absent.
    function mins(hhmm) {
        const p = String(hhmm).split(":");
        return (parseInt(p[0]) || 0) * 60 + (parseInt(p[1]) || 0);
    }
    function inRange(s, e, t) {
        return s <= e ? (t >= s && t < e) : (t >= s || t < e);
    }
    function localPhase() {
        const s = Config.schedule;
        const now = new Date();
        const t = now.getHours() * 60 + now.getMinutes();
        const d = mins(s.day), u = mins(s.dusk), n = mins(s.night);
        if (inRange(d, u, t)) return "day";
        if (inRange(u, n, t)) return "dusk";
        return "night";
    }
}
