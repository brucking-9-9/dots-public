pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// nixos-rebuild progress for the top strip (SwitchHud). The rebuild runs in
// the `nixos-switch` user unit (quickshell-bottom.nix), not under the bar:
// the switch restarts quickshell.service, so the bar only reads the unit's
// files in $XDG_RUNTIME_DIR/nixos-switch and picks up a run in progress
// after its own restart.
//   log     nixos-rebuild output; stays empty until sudo has authenticated
//   status  exit code, written when the run ends
// States: idle | running | ok | failed. dismiss() renames log → log.last so
// a finished run doesn't come back on the next bar restart.
Singleton {
    id: root
    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") + "/nixos-switch"
    property string logText: ""
    property string statusText: ""

    readonly property string state: {
        const st = statusText.trim();
        if (st !== "") return logText === "" ? "idle" : (st === "0" ? "ok" : "failed");
        return logText !== "" ? "running" : "idle";
    }
    // last non-empty lines (the hover view), ANSI codes and store hashes stripped
    readonly property var lines: {
        const out = [];
        const ls = logText.split("\n");
        for (let i = ls.length - 1; i >= 0 && out.length < 10; i--) {
            const l = ls[i].replace(/\x1b\[[0-9;]*[A-Za-z]/g, "").replace(/\/nix\/store\/[a-z0-9]{32}-/g, "").trim();
            if (l !== "") out.unshift(l);
        }
        return out;
    }
    readonly property string line: lines.length ? lines[lines.length - 1] : ""
    // start of the run the HUD's elapsed counter measures: stamped on every
    // entry into "running" (nixos-switch truncates the log before it clears
    // status, so a finished run goes ok/failed → idle → running; an undismissed
    // one must not hand its stamp to the next)
    property real startedAt: 0
    onStateChanged: if (state === "running") startedAt = Date.now()

    function start() {
        Niri.spawn(["nixos-switch"]);
    }
    function dismiss() {
        Quickshell.execDetached(["sh", "-c", 'cd "$1" && mv -f log log.last && rm -f status', "sh", dir]);
        logText = ""; statusText = ""; startedAt = 0;
    }
    // one shell: the rename lands before the viewer opens (two detached
    // processes raced); the spawn still goes through niri for the session env
    function openLog() {
        Quickshell.execDetached(["sh", "-c", 'cd "$1" && mv -f log log.last && rm -f status; exec niri msg action spawn -- kitty --title "nixos-switch log" less -R +G "$1/log.last"', "sh", dir]);
        logText = ""; statusText = ""; startedAt = 0;
    }

    FileView {
        id: logFile
        path: root.dir + "/log"
        printErrors: false
        onLoaded: root.logText = text()
        onLoadFailed: root.logText = ""
    }
    FileView {
        id: statusFile
        path: root.dir + "/status"
        printErrors: false
        onLoaded: root.statusText = text()
        onLoadFailed: root.statusText = ""
    }
    // the files appear only once a run starts, so poll (tmpfs, tiny files):
    // quick while a run is live, slow otherwise
    Timer {
        interval: root.state === "idle" ? 1500 : 400
        running: true
        repeat: true
        onTriggered: { logFile.reload(); statusFile.reload(); }
    }
}
