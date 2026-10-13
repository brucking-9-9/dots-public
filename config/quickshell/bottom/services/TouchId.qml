pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Touch ID prompt state, from the t2-touchid bridge's broadcast on the system
// bus (org.kait2en.TouchId.Changed, any user may listen; the methods are
// root-only). States: idle | waiting | scanning | matched | retry | failed.
// `matched`/`failed` are held ~1.2 s because the daemon drops to `idle` the
// moment fprintd closes the device, which can be immediate.
Singleton {
    id: root

    property string state: "idle"

    function set(s) {
        if (s === "matched" || s === "failed") hold.restart();
        else hold.stop();
        state = s;
    }

    function handle(line) {
        // "Changed ('waiting',)"; the two header lines and the owner-change
        // notices gdbus prints around a daemon restart don't match
        const m = /Changed \('(\w+)',\)/.exec(line);
        if (m) {
            if (m[1] === "idle" && hold.running) return;   // keep the verdict on screen
            set(m[1]);
        } else if (/^The name .* (does not have an owner|is owned by)/.test(line)) {
            // bridge (re)started mid-prompt: whatever was pending is gone
            if (!hold.running) state = "idle";
        }
    }

    Timer {
        id: hold
        interval: 1200
        onTriggered: root.state = "idle"
    }

    Process {
        id: mon
        command: ["gdbus", "monitor", "--system", "--dest", "org.kait2en.TouchId", "--object-path", "/org/kait2en/TouchId"]
        running: true
        stdout: SplitParser {
            onRead: data => root.handle(data)
        }
        onExited: { root.state = "idle"; restart.start(); }
    }

    Timer {
        id: restart
        interval: 2000
        onTriggered: mon.running = true
    }
}
