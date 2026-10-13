pragma Singleton
import QtQuick
import Quickshell

// Desktop-entry search for the launcher prompt.
Singleton {
    id: root

    function appId(e) {
        return String(e.startupClass || e.id || "").toLowerCase();
    }

    function search(q) {
        q = q.trim().toLowerCase();
        if (!q) return [];
        const all = DesktopEntries.applications.values.filter(e => !e.noDisplay);
        const starts = [], contains = [];
        for (const e of all) {
            const n = e.name.toLowerCase();
            if (n.startsWith(q)) starts.push(e);
            else if (n.includes(q) || root.appId(e).includes(q)) contains.push(e);
        }
        const byName = (a, b) => a.name.localeCompare(b.name);
        return starts.sort(byName).concat(contains.sort(byName)).slice(0, 8);
    }

    // Command line for a desktop entry. Terminal=true entries (btop, hx, …)
    // go through xdg-terminal-exec (the XDG default-terminal spec; which
    // terminal is declared once in home-manager, see terminal/kitty.nix),
    // asking for `id` as the window app-id so the running dot and
    // focus-cycling find the window under the same id the caller stores.
    function command(e, id) {
        const cmd = e.command.slice();
        if (!e.runInTerminal) return cmd;
        return ["xdg-terminal-exec", "--app-id=" + id, "--"].concat(cmd);
    }

    function launch(e) {
        if (!e) return;
        const id = root.appId(e);
        // run through niri so the app gets the session environment
        Niri.focusOrSpawn(id, root.command(e, id));
    }
}
