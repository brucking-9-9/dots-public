pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Backend of the top bar's power glyph: `power-cycle status` (power/quiet.nix)
// prints the same JSON waybar's custom/power read — alt = ppd profile,
// class includes "quiet" while the quiet-mode unit is up, tooltip = the
// text waybar showed. Polled every 5 s as waybar did; `power-cycle` also
// pokes `qs ipc -c bottom call top refresh` after a flip.
Singleton {
    id: root

    property string profile: "balanced"
    property bool quiet: false
    property string tooltip: ""

    function refresh() { status.running = true; }
    // through niri so power-cycle gets the login PATH / sudo rules, as a bar click did under waybar
    function next() { Niri.spawn(["power-cycle", "next"]); }
    function toggleQuiet() { Niri.spawn(["power-cycle", "toggle"]); }

    Process {
        id: status
        running: true
        command: ["power-cycle", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                let s; try { s = JSON.parse(text); } catch (e) { return; }
                root.profile = s.alt || "balanced";
                root.quiet = (s.class || []).indexOf("quiet") !== -1;
                root.tooltip = s.tooltip || "";
            }
        }
    }
    Timer { interval: 5000; running: true; repeat: true; onTriggered: root.refresh() }
}
