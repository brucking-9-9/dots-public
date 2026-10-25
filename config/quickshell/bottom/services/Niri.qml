pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// niri state via `niri msg --json event-stream`. Arrays are reassigned (never
// mutated in place) after every event so QML bindings re-evaluate.
Singleton {
    id: root

    property var workspaces: []
    property var windows: []

    readonly property string focusedAppId: {
        const w = windows.find(w => w.is_focused);
        return w ? String(w.app_id || "").toLowerCase() : "";
    }

    // distinct app_ids with at least one window, most recently focused first
    readonly property var runningAppIds: {
        const sorted = windows.slice().sort((a, b) => ts(b) - ts(a));
        const out = [];
        for (const w of sorted) {
            const id = String(w.app_id || "").toLowerCase();
            if (id && !out.includes(id)) out.push(id);
        }
        return out;
    }

    // a window belongs to an app id when they match exactly or the window's
    // reverse-DNS id ends in it (md.obsidian.Obsidian ↔ the "obsidian" pin)
    function sameApp(windowId, appId) {
        const w = String(windowId || "").toLowerCase();
        return w === appId || w.endsWith("." + appId);
    }

    function ts(w) { return w.focus_timestamp ? w.focus_timestamp.secs : 0; }

    function workspacesFor(output) {
        return workspaces.filter(w => w.output === output).sort((a, b) => a.idx - b.idx);
    }

    function occupied(wsId) { return windows.some(w => w.workspace_id === wsId); }

    function hasWindow(appId) {
        return windows.some(w => sameApp(w.app_id, appId));
    }

    // Focus the most recent window of appId; if that one is already focused,
    // cycle to the next; with none running, spawn cmd through niri so the app
    // inherits niri's environment rather than this unit's.
    function focusOrSpawn(appId, cmd) {
        const m = windows
            .filter(w => sameApp(w.app_id, appId))
            .sort((a, b) => ts(b) - ts(a));
        if (m.length) {
            let target = m[0];
            if (target.is_focused && m.length > 1) target = m[m.length - 1];
            Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(target.id)]);
        } else {
            Quickshell.execDetached(["niri", "msg", "action", "spawn", "--"].concat(cmd));
        }
    }

    // run a command through niri so it inherits the session environment
    // (login PATH, sudo rules) rather than the quickshell unit's
    function spawn(cmd) {
        Quickshell.execDetached(["niri", "msg", "action", "spawn", "--"].concat(cmd));
    }

    function windowsOf(appId) {
        return windows.filter(w => sameApp(w.app_id, appId));
    }
    // ask every window of the app to close (graceful, like the WM close bind)
    function closeApp(appId) {
        for (const w of windowsOf(appId))
            Quickshell.execDetached(["niri", "msg", "action", "close-window", "--id", String(w.id)]);
    }
    // SIGKILL the processes behind the app's windows (for hung apps/games)
    function killApp(appId) {
        const pids = [];
        for (const w of windowsOf(appId)) if (w.pid && !pids.includes(String(w.pid))) pids.push(String(w.pid));
        if (pids.length) Quickshell.execDetached(["kill", "-9"].concat(pids));
    }

    Process {
        id: stream
        command: ["niri", "msg", "--json", "event-stream"]
        running: true
        stdout: SplitParser {
            onRead: data => root.handle(data)
        }
        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 2000
        onTriggered: stream.running = true
    }

    function handle(line) {
        let ev;
        try { ev = JSON.parse(line); } catch (e) { return; }

        if (ev.WorkspacesChanged) {
            workspaces = ev.WorkspacesChanged.workspaces;
        } else if (ev.WorkspaceActivated) {
            const id = ev.WorkspaceActivated.id;
            const focused = ev.WorkspaceActivated.focused;
            const hit = workspaces.find(w => w.id === id);
            const out = hit ? hit.output : null;
            workspaces = workspaces.map(w => {
                const c = Object.assign({}, w);
                if (w.output === out) c.is_active = (w.id === id);
                if (focused) c.is_focused = (w.id === id);
                return c;
            });
        } else if (ev.WorkspaceUrgencyChanged) {
            const e = ev.WorkspaceUrgencyChanged;
            workspaces = workspaces.map(w => w.id === e.id ? Object.assign({}, w, { is_urgent: e.urgent }) : w);
        } else if (ev.WorkspaceActiveWindowChanged) {
            const e = ev.WorkspaceActiveWindowChanged;
            workspaces = workspaces.map(w => w.id === e.workspace_id ? Object.assign({}, w, { active_window_id: e.active_window_id }) : w);
        } else if (ev.WindowsChanged) {
            windows = ev.WindowsChanged.windows;
        } else if (ev.WindowOpenedOrChanged) {
            const w = ev.WindowOpenedOrChanged.window;
            const rest = windows.filter(x => x.id !== w.id)
                .map(x => w.is_focused && x.is_focused ? Object.assign({}, x, { is_focused: false }) : x);
            windows = rest.concat([w]);
        } else if (ev.WindowClosed) {
            windows = windows.filter(w => w.id !== ev.WindowClosed.id);
        } else if (ev.WindowFocusChanged) {
            const id = ev.WindowFocusChanged.id;
            windows = windows.map(w => Object.assign({}, w, { is_focused: w.id === id }));
        } else if (ev.WindowUrgencyChanged) {
            const e = ev.WindowUrgencyChanged;
            windows = windows.map(w => w.id === e.id ? Object.assign({}, w, { is_urgent: e.urgent }) : w);
        }
    }
}
