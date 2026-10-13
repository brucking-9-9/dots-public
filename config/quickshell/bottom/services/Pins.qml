pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Runtime pinning: ~/.local/state/quickshell-bottom/pins.json
//   {"pins":[{"appId":"obsidian","name":"obsidian","cmd":["obsidian"]}, …],
//    …}
// Seeded from Config.defaultPins (resolved through desktop entries) when the
// file is missing or empty.
Singleton {
    id: root

    readonly property string dir: Config.home + "/.local/state/quickshell-bottom"
    property var pins: []
    property bool ready: false
    property bool dirReady: false

    Process {
        command: ["mkdir", "-p", root.dir]
        running: true
        onExited: root.dirReady = true
    }

    // wait for both the state dir and the config defaults before loading
    readonly property bool canLoad: dirReady && Config.ready
    onCanLoadChanged: if (canLoad) file.path = dir + "/pins.json"

    FileView {
        id: file
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const a = adapter.pins;
            if (Array.isArray(a) && a.length) {
                root.pins = a;
                root.ready = true;
            } else {
                root.seed();
            }
        }
        onLoadFailed: root.seed()

        JsonAdapter {
            id: adapter
            property var pins: []
        }
    }

    function save() {
        adapter.pins = pins;
        file.writeAdapter();
    }

    function seed() {
        const out = [];
        for (const id of Config.defaultPins) out.push(resolve(String(id)));
        pins = out;
        ready = true;
        save();
    }

    function resolve(id) {
        // helix gets its own app-id so it shows a separate running dot
        if (id === "hx") return { appId: "hx", name: "hx", cmd: ["kitty", "--app-id", "hx", "hx"] };
        const e = DesktopEntries.heuristicLookup(id);
        if (e) { const a = String(e.startupClass || id).toLowerCase(); return { appId: a, name: id, cmd: Apps.command(e, a) }; }
        return { appId: id, name: id, cmd: [id] };
    }

    function isPinned(appId) { return pins.some(p => Niri.sameApp(appId, p.appId) || Niri.sameApp(p.appId, appId)); }

    function pinEntry(e) {
        const id = Apps.appId(e);
        if (!id || isPinned(id)) return;
        pins = pins.concat([{ appId: id, name: e.name.toLowerCase(), cmd: Apps.command(e, id) }]);
        save();
    }

    // pin a running app by its niri app_id (transient chip → pin)
    function pinAppId(appId) {
        if (!appId || isPinned(appId)) return;
        const e = DesktopEntries.heuristicLookup(appId);
        pins = pins.concat([{ appId: appId, name: appId, cmd: e ? Apps.command(e, appId) : [appId] }]);
        save();
    }

    function unpin(i) {
        const p = pins.slice();
        p.splice(i, 1);
        pins = p;
        save();
    }

    function move(i, d) {
        const j = i + d;
        if (j < 0 || j >= pins.length) return;
        const p = pins.slice();
        const t = p[i]; p[i] = p[j]; p[j] = t;
        pins = p;
        save();
    }

    function activate(i) {
        const p = pins[i];
        if (p) Niri.focusOrSpawn(p.appId, p.cmd);
    }
}
