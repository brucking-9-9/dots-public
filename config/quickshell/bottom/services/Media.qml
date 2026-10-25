pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

// Active MPRIS player + cava levels. Quickshell's Pipewire service is a VU
// meter, not a spectrum, so the bars come from a cava process that only runs
// while something is playing (the media island is on screen exactly then).
Singleton {
    id: root

    readonly property var player: {
        const ps = Mpris.players.values;
        const playing = ps.find(p => p.isPlaying);
        return playing ? playing : (ps.length ? ps[0] : null);
    }

    property var levels: []   // 72 ints 0..100 (cava.conf)
    readonly property bool barsActive: player !== null && player.isPlaying

    Process {
        id: cava
        command: ["cava", "-p", Quickshell.shellPath("cava.conf")]
        running: root.barsActive
        stdout: SplitParser {
            onRead: data => {
                const v = data.split(";").filter(s => s.length).map(Number);
                if (v.length) root.levels = v;
            }
        }
    }

    onBarsActiveChanged: if (!barsActive) levels = []

    function level(i) {
        return i < levels.length ? levels[i] : 0;
    }

    function fmt(s) {
        s = Math.max(0, Math.floor(s || 0));
        const m = Math.floor(s / 60), r = s % 60;
        return String(m).padStart(2, "0") + ":" + String(r).padStart(2, "0");
    }

    function esc(s) {
        return String(s || "").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }
}
