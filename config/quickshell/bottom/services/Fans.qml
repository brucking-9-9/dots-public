pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Fan speeds + manual override for the sys island's fan widget. Reads the
// applesmc nodes and the state dirs of the `fan-manual` / `quiet-mode` units
// (power/quiet.nix) every 2 s — all world-readable, so no sudo to poll;
// changes go through the `fan` wrapper (sudo quiet-root, NOPASSWD).
Singleton {
    id: root

    property int rpm1: 0
    property int rpm2: 0
    property int level: 0           // % of the min→max range: the pinned one, else where fan1 sits
    property bool manual: false     // fan-manual unit up
    property bool quiet: false      // quiet mode owns the fans
    property bool ok: false
    readonly property int rpm: Math.round((rpm1 + rpm2) / 2)

    // Wheel/clicks set `want` right away (the widget shows it) and the spawn
    // waits for the wheel to settle: each `fan N` is sudo + systemd.
    property int want: -1
    readonly property int shown: want >= 0 ? want : level

    function nudge(d) {
        if (quiet) return;
        want = Math.max(0, Math.min(100, Math.round((shown + d) / 5) * 5));
        push.restart();
    }
    function toggle() {
        if (quiet) return;
        push.stop();
        Niri.spawn(manual ? ["fan", "auto"] : ["fan", String(shown)]);
        manual = !manual;   // optimistic; the next sample corrects it
        want = -1;
    }
    readonly property bool atMax: !quiet && (manual || want >= 0) && shown === 100
    // the mini glyph's click: max ↔ auto
    function cycle() { atMax ? toggle() : set(100); }
    function set(pct) {
        if (quiet) return;
        want = pct; push.restart();
    }

    Timer {
        id: push
        interval: 350
        onTriggered: { Niri.spawn(["fan", String(root.want)]); root.manual = true; hold.restart(); }
    }
    // keep showing `want` until the unit has picked it up
    Timer { id: hold; interval: 2500; onTriggered: root.want = -1 }

    Process {
        id: sampler
        running: true
        command: ["bash", "-c", `
s=/sys/bus/acpi/devices/APP0001:00
while :; do
  read -r i1 < $s/fan1_input; read -r i2 < $s/fan2_input
  read -r mn < $s/fan1_min; read -r mx < $s/fan1_max
  man=0; pct=-1; q=0
  [ -r /run/fan-manual/pct ] && read -r pct < /run/fan-manual/pct && man=1
  [ -d /run/quiet-mode ] && q=1
  [ "$pct" -lt 0 ] && pct=$(( (i1 - mn) * 100 / (mx - mn) ))
  echo "$i1 $i2 $pct $man $q"
  sleep 2
done`]
        stdout: SplitParser {
            onRead: line => {
                const f = line.trim().split(" ").map(Number);
                if (f.length !== 5 || f.some(isNaN)) return;
                root.rpm1 = f[0]; root.rpm2 = f[1];
                root.level = Math.max(0, Math.min(100, f[2]));
                root.manual = f[3] === 1; root.quiet = f[4] === 1;
                root.ok = true;
            }
        }
        onExited: restart.start()
    }
    Timer { id: restart; interval: 3000; onTriggered: sampler.running = true }
}
