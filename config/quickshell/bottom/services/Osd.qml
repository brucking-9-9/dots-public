pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// On-screen display backend (replaced swayosd, Oct 2026). The niri media/
// brightness binds call `qs ipc -c bottom call osd <volume|mic|brightness|
// kbd|media> <op>`; this performs the change and `Osd.qml` shows it for a
// moment. Volume/mic go through the Pipewire service (Audio), media through
// the Mpris player the island already drives, the two backlights through
// brightnessctl (sysfs needs its udev rules; the unit PATH carries it).
// Caps lock is watched, not bound (a niri bind would swallow the key): `caps`
// follows the keyboards' capslock LEDs and each change pops the HUD; the sys
// island shows a tag while it is on.
Singleton {
    id: root

    property string kind: ""       // volume | mic | brightness | kbd | media | caps
    property bool caps: false      // any keyboard's capslock LED lit
    property string mediaOp: ""    // play | pause | next | prev | stop (kind media; toggle resolves to play/pause)
    property bool shown: false
    property real screenLevel: 0   // 0..1, read back from brightnessctl
    property real kbdLevel: 0
    readonly property real step: 0.05

    function show(k) {
        kind = k;
        shown = true;
        hide.restart();            // a held key keeps it up
    }
    Timer {
        id: hide
        interval: 1500
        onTriggered: root.shown = false
    }

    // the LED's input number changes on replug/resume and every keyboard has
    // its own, so one small loop reads them all and prints 0/1 on change
    // (sysfs LEDs don't notify). The first line is the state at startup: no pop.
    // The pause is `read -t` on a pipe nothing writes to: no `sleep` fork five
    // times a second.
    Process {
        id: capsWatch
        running: true
        property bool primed: false
        command: ["bash", "-c", 'exec {fd}<> <(:); prev=; while :; do s=0; for f in /sys/class/leds/*::capslock/brightness; do v=0; read -r v < "$f" 2>/dev/null; [ "$v" = 0 ] || s=1; done; [ "$s" = "$prev" ] || { echo "$s"; prev=$s; }; read -t 0.2 -u "$fd" _; done']
        stdout: SplitParser {
            onRead: line => {
                root.caps = line.trim() === "1";
                if (capsWatch.primed) root.show("caps");
                capsWatch.primed = true;
            }
        }
    }

    function volume(op) {
        if (op === "raise") Audio.changeVolume(step);
        else if (op === "lower") Audio.changeVolume(-step);
        else if (op === "mute-toggle") Audio.toggleMute();
        show("volume");
    }
    function mic(op) {
        if (op === "raise") Audio.changeMic(step);
        else if (op === "lower") Audio.changeMic(-step);
        else if (op === "mute-toggle") Audio.toggleMicMute();
        show("mic");
    }

    // screen: acpi_video0 on this T2 (not intel_backlight), 5 % steps, never
    // below 1 so a held key can't black the panel; keyboard: 10 % steps.
    // --min-value takes an OPTIONAL argument: a separate "1" after -n is a
    // stray word and brightnessctl silently changes nothing (exit 0)
    function screenBrightness(op) { backlight.run("brightness", "acpi_video0", op === "lower" ? "5%-" : "5%+", ["--min-value=1"]); }
    function kbdBrightness(op)    { backlight.run("kbd", "apple::kbd_backlight", op === "lower" ? "10%-" : "10%+", []); }
    // the top bar's backlight slider / wheel: an absolute percentage, HUD optional
    function setScreen(pct, silent) { backlight.run("brightness", "acpi_video0", pct + "%", ["--min-value=1"], silent === true); }

    // one brightnessctl at a time; a key repeat that lands mid-run is queued
    Process {
        id: backlight
        property string target: ""
        property bool silent: false
        property var pending: null
        // options go before `set`: brightnessctl takes the first word after it as the value
        function run(k, dev, value, opts, quiet) {
            if (running) { pending = [k, dev, value, opts, quiet]; return; }
            target = k;
            silent = quiet === true;
            command = ["brightnessctl", "-m", "-d", dev, ...opts, "set", value];
            running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                // "acpi_video0,backlight,24,24%,100": value / max
                const f = text.trim().split("\n").pop().split(",");
                if (f.length >= 5) {
                    const v = Number(f[2]) / Math.max(1, Number(f[4]));
                    if (backlight.target === "kbd") root.kbdLevel = v;
                    else root.screenLevel = v;
                }
                if (!backlight.silent) root.show(backlight.target);
            }
        }
        onExited: {
            if (pending) { const p = pending; pending = null; run(...p); }
        }
    }

    // the HUD shows the action taken, decided here from the state before the
    // call: spotify-player's MPRIS status lags a toggle by well over the
    // popup's lifetime, so a live isPlaying binding would show the old state
    function media(op) {
        const p = Media.player;
        if (op === "toggle") op = p && p.isPlaying ? "pause" : "play";
        mediaOp = op;
        if (p) {
            if (op === "next") { if (p.canGoNext) p.next(); }
            else if (op === "prev") { if (p.canGoPrevious) p.previous(); }
            else if (op === "stop") { if (p.canControl) p.stop(); }
            else if (p.canTogglePlaying) p.togglePlaying();
        }
        show("media");
    }
}
