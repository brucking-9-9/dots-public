pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper strip backend: awww does the drawing, we remember the choice in
// ~/.local/state/wallpaper/current (niri re-applies it at startup).
//
// awww's client decodes and uploads every frame of an animated file before
// the daemon shows it, which for a 4K GIF takes a long time. So: all awww
// calls go through ONE process (a new request kills the one in flight),
// animated files are never previewed on hover, and `busy` tells the strip
// which file is still loading.
Singleton {
    id: root

    readonly property string dir: Config.wallpaperDir
    readonly property string stateDir: Config.home + "/.local/state/wallpaper"
    property var files: []
    property string current: ""
    property string shown: ""     // what awww is displaying (or loading) right now
    property string busy: ""      // path the awww client is still working on

    function animated(p) { return /\.(gif|webp)$/i.test(String(p)); }
    function name(p) { return String(p).split("/").pop().replace(/\.[^.]+$/, ""); }

    // the dir also holds an .mp4 awww can't play, so filter by extension
    Process {
        id: scan
        command: ["find", root.dir, "-maxdepth", "1", "-type", "f", "(",
            "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg",
            "-o", "-iname", "*.gif", "-o", "-iname", "*.webp", ")"]
        stdout: StdioCollector {
            onStreamFinished: root.files = text.split("\n").filter(s => s.length).sort()
        }
    }

    Process {
        id: query
        command: ["awww", "query"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/image: (.+)$/m);
                if (m) {
                    root.current = m[1].trim();
                    root.shown = root.current;
                }
            }
        }
    }

    // the single awww client; `pending` is applied when it exits (or is killed)
    property var pending: null
    Process {
        id: client
        onExited: {
            root.busy = "";
            if (root.pending) {
                const p = root.pending;
                root.pending = null;
                root.run(p.path, p.dur);
            }
        }
    }

    function run(p, dur) {
        if (client.running) {
            pending = { path: p, dur: dur };
            client.running = false;      // kill the one in flight; onExited starts this one
            return;
        }
        shown = p;
        busy = p;
        client.command = ["awww", "img", p, "--transition-type", "fade", "--transition-duration", String(dur)];
        client.running = true;
    }

    Component.onCompleted: rescan()

    function rescan() {
        scan.running = true;
        query.running = true;
    }

    // hover: static images only; animated ones take too long to be a preview
    function preview(p) {
        restoreTimer.stop();
        if (animated(p)) return;
        if (p !== shown) run(p, 0.25);
    }

    function set(p) {
        restoreTimer.stop();
        current = p;
        if (p !== shown) run(p, 0.4);
        // remember for niri's spawn-at-startup line; args via $1/$2 so paths never hit the shell parser
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "%s\\n" "$2" > "$1/current"', "sh", stateDir, p]);
    }

    // called when the pointer leaves a thumbnail; preview() of the next one cancels it
    function restoreSoon() { restoreTimer.restart(); }

    function restore() {
        restoreTimer.stop();
        if (current && shown !== current) run(current, 0.25);
    }

    Timer {
        id: restoreTimer
        interval: 250
        onTriggered: root.restore()
    }
}
