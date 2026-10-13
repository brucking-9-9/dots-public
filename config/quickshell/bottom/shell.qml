import QtQuick
import Quickshell
import Quickshell.Io
import "services"

// Bottom "scanline rail" for niri. One Bar per screen; `qs ipc -c bottom
// call bar <open|close|toggle|summon|strip|notifs|dnd|silent>` drives it (niri binds Mod+B
// to toggle and Mod+D to summon).
ShellRoot {
    id: shell

    function eachBar(f) {
        for (let i = 0; i < bars.instances.length; i++) f(bars.instances[i]);
    }

    Variants {
        id: bars
        model: Quickshell.screens
        Bar {}
    }
    // notification popups, top-right (the Notif service is the daemon)
    Variants {
        model: Quickshell.screens
        NotifPopups {}
    }
    // fingerprint prompt HUD above the bar (the TouchId service listens to the T2 bridge)
    Variants {
        model: Quickshell.screens
        TouchIdHud {}
    }

    IpcHandler {
        target: "bar"
        function open(): void { shell.eachBar(b => b.openAll()); }
        function close(): void { shell.eachBar(b => b.closeAll()); }
        function toggle(): void { shell.eachBar(b => b.toggle()); }
        function summon(): void { shell.eachBar(b => b.toggleSummon()); }
        function strip(): void { shell.eachBar(b => b.toggleStrip()); }
        function notifs(): void { shell.eachBar(b => b.toggleNotifs()); }
        // niri binds Mod+Shift+N to `dnd`; `silent` mutes the chime
        function dnd(): void { Notif.toggleDnd(); }
        function silent(): void { Notif.toggleSilent(); }
        // scripts: fire the newest open notification's first action / dismiss everything
        function act(): void { const e = Notif.live[0]; if (e && e.actions.length) Notif.invoke(e, e.actions[0].id); }
        function dismissall(): void { Notif.dismissAll(); }
        function apps(): void { shell.eachBar(b => b.appsOpen = !b.appsOpen); }
        function media(): void { shell.eachBar(b => b.toggleMedia()); }
        function sys(): void { shell.eachBar(b => b.sysOpen = !b.sysOpen); }
        // open the launcher with a query already typed (debugging / scripts)
        function search(q: string): void { shell.eachBar(b => b.search(q)); }
        // niri binds Mod+Alt+N / Mod+Alt+Shift+N to these: the bar's pins
        // (1-based, as the chips are numbered) without the launcher ever opening
        function pin(n: int): void { Pins.activate(n - 1); }
        function killpin(n: int): void { const p = Pins.pins[n - 1]; if (p) Niri.killApp(p.appId); }
        function state(): string {
            const b = bars.instances[0];
            return JSON.stringify({ apps: b.appsOpen, media: b.mediaOpen, sys: b.sysOpen, notifs: b.notifOpen, strip: b.stripOpen, locked: b.allLocked, summoned: b.summoned, pending: b.pendingCount,
                barsActive: Media.barsActive, playing: Media.player ? Media.player.isPlaying : null, levels: Media.levels.length });
        }
    }

    // `qs ipc -c bottom call night set 3000` / `night auto` / `night get`
    IpcHandler {
        target: "night"
        function set(k: int): void { Night.setManual(k); }
        function auto(): void { Night.auto(); }
        function get(): string { return Night.label + " " + Night.currentPhase + " " + Night.mode; }
    }

    // `qs ipc -c bottom call touchid set waiting|scanning|matched|retry|failed|idle` fakes a prompt
    IpcHandler {
        target: "touchid"
        function set(s: string): void { TouchId.set(s); }
        function get(): string { return TouchId.state; }
    }
}
