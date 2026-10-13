pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon: this singleton owns org.freedesktop.Notifications
// (mako is retired). `live` = notifications still open, `popups` = the ones
// shown top-right by NotifPopups.qml (newest first, at most maxPopups),
// `history` = what was closed, listed under ✉ until cleared (tap re-shows).
// dnd hides popups (still counted and listed), silent drops the chime; both
// persist with the history in ~/.local/state/quickshell-bottom/notif.json.
// Entries are plain snapshots {key, id, app, summary, body, urgency 0-2, icon,
// image, time, actions [{id, text}], timeout ms (0 = sticky), win, desktop, n}
// where win is the sender's niri window id (x-niri-window hint, 0 = none), n is
// the live Notification object (null for history / restored popups).
Singleton {
    id: root
    property var live: []
    property var popups: []
    property var closing: []     // keys sliding out (NotifPopups animates, flush removes)
    property var history: []
    property bool dnd: false
    property bool silent: false
    property bool clearing: false
    readonly property int pending: live.length + history.length
    readonly property int maxPopups: 5
    readonly property int maxHistory: 60

    NotificationServer {
        id: server
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true
        keepOnReload: true
        onNotification: n => { n.tracked = true; root.add(n, false); }
    }
    // after a hot reload the tracked notifications survive but our handlers don't
    Component.onCompleted: {
        const t = server.trackedNotifications.values;
        for (let i = 0; i < t.length; i++) root.add(t[i], true);
    }

    function iconFor(n) {
        const ic = String(n.appIcon || "");
        if (ic.startsWith("/") || ic.startsWith("file:")) return ic;
        let p = ic ? Quickshell.iconPath(ic, true) : "";
        if (!p && n.desktopEntry) {
            const d = DesktopEntries.byId(n.desktopEntry);
            if (d && d.icon) p = Quickshell.iconPath(d.icon, true);
        }
        return p || "";
    }

    function entry(n) {
        const acts = [];
        for (let i = 0; i < n.actions.length; i++) acts.push({ id: n.actions[i].identifier, text: n.actions[i].text });
        const urg = n.urgency === NotificationUrgency.Critical ? 2 : (n.urgency === NotificationUrgency.Low ? 0 : 1);
        const t = n.expireTimeout;   // -1 = default, 0 = never (critical always sticks)
        const timeout = (urg === 2 || t === 0) ? 0 : (t > 0 ? t : (urg === 0 ? 3500 : 6000));
        return { key: n.id + "@" + Date.now(), id: n.id, app: String(n.appName || ""),
                 summary: String(n.summary || ""), body: String(n.body || ""), urgency: urg,
                 icon: iconFor(n), image: String(n.image || ""), time: Date.now(),
                 actions: acts, timeout: timeout, win: Number(n.hints["x-niri-window"] || 0),
                 desktop: String(n.desktopEntry || ""), n: n };
    }

    function add(n, quiet) {
        const e = entry(n);
        live = [e].concat(live.filter(x => x.id !== e.id));
        n.closed.connect(reason => root.onClosed(e.id));
        if (quiet || dnd) return;
        popups = [e].concat(popups.filter(x => x.id !== e.id)).slice(0, maxPopups);
        if (!silent && e.urgency > 0) chime();
    }

    function onClosed(id) {
        const e = live.find(x => x.id === id);
        live = live.filter(x => x.id !== id);
        for (const p of popups) if (p.id === id && p.n) unpop(p.key);
        if (!e || clearing || e.n["transient"]) return;
        // keep theme icons (image://icon/…) for the list; image-data blobs die with the process
        const img = e.image.startsWith("image://icon/") ? e.image : "";
        const h = Object.assign({}, e, { n: null, image: img, actions: [], timeout: 0 });
        history = [h].concat(history).slice(0, maxHistory);
        save();
    }

    // slide-out first (NotifPopups watches `closing`), then drop from the model
    function unpop(key) {
        if (closing.indexOf(key) >= 0 || !popups.some(x => x.key === key)) return;
        closing = closing.concat([key]);
        flush.restart();
    }
    Timer {
        id: flush
        interval: 260
        onTriggered: {
            const c = root.closing;
            root.popups = root.popups.filter(x => c.indexOf(x.key) < 0);
            root.closing = [];
        }
    }

    function expire(e) { if (e.n) e.n.expire(); else unpop(e.key); }
    function dismiss(e) { if (e.n) e.n.dismiss(); else unpop(e.key); }
    function invoke(e, actionId) {
        if (!e.n) return;
        const a = e.n.actions;
        // invoke() closes a non-resident notification itself
        for (let i = 0; i < a.length; i++) if (a[i].identifier === actionId) { a[i].invoke(); break; }
    }
    // The window a notification belongs to: the one its sender named, else the
    // most recently focused window of its app.
    function windowFor(e) {
        const ws = Niri.windows;
        if (e.win) { const w = ws.find(w => w.id === e.win); if (w) return w; }
        const ids = [e.desktop, e.app].map(s => String(s || "").toLowerCase()).filter(s => s.length > 0);
        const m = ws.filter(w => ids.some(id => Niri.sameApp(w.app_id, id))).sort((a, b) => Niri.ts(b) - Niri.ts(a));
        return m.length ? m[0] : null;
    }
    // Jump to that window and close the card. A sender's own "take me there"
    // action wins (it closes the notification itself); no window = no-op.
    function goTo(e) {
        if (e.n) for (const a of e.actions) if (a.id === "default" || a.id === "open") { invoke(e, a.id); return; }
        const w = windowFor(e);
        if (!w) return;
        Quickshell.execDetached(["niri", "msg", "action", "focus-window", "--id", String(w.id)]);
        dismiss(e);
    }
    function dismissAll() { for (const e of live.slice()) if (e.n) e.n.dismiss(); }
    function clear() {
        clearing = true;
        dismissAll();
        history = [];
        save();
        clearDone.restart();
    }
    Timer { id: clearDone; interval: 300; onTriggered: root.clearing = false }

    // re-show a history row as a (detached) popup
    function restore(h) {
        const p = Object.assign({}, h, { key: h.key + "r" + Date.now(), timeout: 6000, n: null });
        popups = [p].concat(popups).slice(0, maxPopups);
    }

    function toggleDnd() {
        dnd = !dnd;
        if (dnd) for (const p of popups.slice()) unpop(p.key);
        save();
    }
    function toggleSilent() { silent = !silent; save(); }

    function chime() {
        Quickshell.execDetached(["pw-play", "--media-role=Notification", Config.chime]);
    }

    FileView {
        id: file
        path: Config.home + "/.local/state/quickshell-bottom/notif.json"
        printErrors: false
        onLoaded: {
            root.dnd = !!adapter.dnd;
            root.silent = !!adapter.silent;
            root.history = Array.isArray(adapter.history) ? adapter.history : [];
        }
        JsonAdapter {
            id: adapter
            property bool dnd: false
            property bool silent: false
            property var history: []
        }
    }
    function save() {
        adapter.dnd = dnd;
        adapter.silent = silent;
        adapter.history = history;
        file.writeAdapter();
    }
}
