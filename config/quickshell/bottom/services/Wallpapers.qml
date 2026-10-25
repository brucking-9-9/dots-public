pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Wallpaper strip backend: awww does the drawing, we remember the choice in
// ~/.local/state/wallpaper/current (niri re-applies it at startup).
//
// Subfolders of the wallpaper dir are the strip's tabs (up to two levels,
// e.g. "Dynamic/Dark"): `folders` lists them with counts, loose files at the
// top level show under "misc", and `folder` is the selected tab (defaults to
// the one holding the current wallpaper). `visibleFiles` is what the strip
// renders.
//
// Dynamic wallpapers: Dynamic/Dark/<scene>[-_]dark.png pairs with
// Dynamic/Light/<scene>[-_]light.png (JaKooLit's set; case and separator
// vary per pair). Both dirs fold into ONE "Dynamic" tab with one card per
// pair (the member the current mode shows). Picking a card picks the scene;
// the night schedule's phase picks the variant (Config.dynamicDarkPhases →
// Dark, else Light) unless the strip's ◑ dark chip forced one — that hold
// lasts until the next phase change, like the temperature's manual marker.
// Re-checked on every phase change and at startup (wallpaper-apply resolves
// the same way before the bar is up). `current` is always the variant on
// screen.
//
// awww's client decodes and uploads every frame of an animated file before
// the daemon shows it, which for a 4K GIF takes a long time. So: all awww
// calls go through ONE process (a new request kills the one in flight),
// animated files are never previewed on hover, and `busy` tells the strip
// which file is still loading.
//
// Video (mp4/webm/mkv/mov) is not awww's job at all: wallpaper-video.service
// (mpvpaper, quickshell-bottom.nix) plays the remembered file on top of awww,
// which shows the clip's poster frame (<dir>/.thumbs/<name>.jpg, written by
// wallpaper-ingest) underneath — the same poster is the strip's thumbnail.
// Clips are meant to arrive through Animated-stage → wallpaper-ingest, so the
// stage dir is not scanned. While a clip plays, hover previews are off (they
// would happen behind it).
Singleton {
    id: root

    readonly property string dir: Config.wallpaperDir
    readonly property string stateDir: Config.home + "/.local/state/wallpaper"
    property var files: []        // every image, all folders
    property var folders: []      // [{ name, count }] — name "" = loose top-level files
    property string folder: ""    // selected tab
    readonly property string dynamicFolder: "Dynamic"
    // the Dynamic tab shows one card per pair: the member the current mode wants
    readonly property var visibleFiles: {
        const inTab = files.filter(p => root.folderOf(p) === root.folder);
        if (root.folder !== root.dynamicFolder) return inTab;
        const dark = root.wantDark, at = {}, out = [];
        for (const p of inTab) {
            const b = root.dynamicBase(p);
            if (at[b] === undefined) { at[b] = out.length; out.push(p); }
            else if (root.memberIs(p, dark)) out[at[b]] = p;
        }
        return out;
    }
    property string current: ""
    property string shown: ""     // what awww is displaying (or loading) right now
    property string busy: ""      // path the awww client is still working on

    function video(p) { return /\.(mp4|webm|mkv|mov)$/i.test(String(p)); }
    function animated(p) { return video(p) || /\.(gif|webp)$/i.test(String(p)); }
    // what the strip (and awww) draw for a file: a clip's poster, else the file
    function thumb(p) {
        p = String(p);
        if (!video(p)) return p;
        const i = p.lastIndexOf("/");
        return p.slice(0, i) + "/.thumbs/" + name(p) + ".jpg";
    }
    function name(p) { return String(p).split("/").pop().replace(/\.[^.]+$/, ""); }
    // "" for a file directly in the wallpaper dir, else its directory relative
    // to it ("Dynamic/Dark"); both members of a Dynamic pair report "Dynamic"
    function folderOf(p) {
        if (dynamicBase(p) !== "") return dynamicFolder;
        const rel = String(p).slice(root.dir.length + 1);
        const i = rel.lastIndexOf("/");
        return i < 0 ? "" : rel.slice(0, i);
    }
    function folderLabel(f) {
        if (f === "") return "misc";
        return f.length > 18 ? f.slice(0, 17) + "…" : f;
    }

    // "beach" for …/Dynamic/Dark/Beach-Dark.png, "" for anything else
    function dynamicBase(p) {
        const m = /\/Dynamic\/(Dark|Light)\/(.+)[-_](dark|light)\.[^.]+$/i.exec(String(p));
        return m ? m[2].toLowerCase() : "";
    }
    function isDynamic(p) { return dynamicBase(p) !== ""; }
    function memberIs(p, dark) { return new RegExp("/Dynamic/" + (dark ? "dark" : "light") + "/", "i").test(String(p)); }
    // the pair member the current mode shows (p itself when it is not a pair)
    function variantFor(p) {
        const base = dynamicBase(p);
        if (!base) return p;
        const hit = files.find(f => root.memberIs(f, root.wantDark) && root.dynamicBase(f) === base);
        return hit || p;
    }
    property string phaseOverride: ""   // `qs ipc -c bottom call bar dynamic night|day|auto` (testing)
    readonly property string phase: phaseOverride !== "" ? phaseOverride : Night.currentPhase
    property string darkOverride: ""    // "dark" | "light" from the ◑ chip, cleared by the next phase change
    readonly property bool wantDark: darkOverride !== "" ? darkOverride === "dark" : Config.dynamicDarkPhases.indexOf(phase) >= 0
    onPhaseChanged: { darkOverride = ""; syncSoon.restart(); }
    onWantDarkChanged: syncSoon.restart()
    // the ◑ chip flips at once, the wallpaper follows when the clicking stops:
    // every swap is a 2.5 s awww fade plus a wallpaper-accent run, and a burst
    // of toggles would kill and restart both per click
    Timer {
        id: syncSoon
        interval: 200
        onTriggered: root.syncDynamic()
    }
    function toggleDark() { darkOverride = wantDark ? "light" : "dark"; }
    // swap a Dynamic pair's member when the mode asks for the other one
    function syncDynamic() {
        if (!files.length || !current) return;
        const want = variantFor(current);
        if (want !== current) set(want, 1);
    }

    // filter by extension (the dir also holds .zip files and the like); up to
    // two levels of subfolders become the tabs (hidden dirs and the ingest
    // stage skipped)
    Process {
        id: scan
        command: ["find", root.dir, "-mindepth", "1", "-maxdepth", "3", "-not", "-path", "*/.*", "-not", "-path", "*/Animated-stage/*", "-type", "f", "(",
            "-iname", "*.png", "-o", "-iname", "*.jpg", "-o", "-iname", "*.jpeg",
            "-o", "-iname", "*.gif", "-o", "-iname", "*.webp",
            "-o", "-iname", "*.mp4", "-o", "-iname", "*.webm", "-o", "-iname", "*.mkv", "-o", "-iname", "*.mov", ")"]
        stdout: StdioCollector {
            onStreamFinished: {
                const all = text.split("\n").filter(s => s.length).sort();
                const counts = {}, pairs = {};
                for (const p of all) {
                    const f = root.folderOf(p);
                    if (f === root.dynamicFolder) {   // one per pair
                        const b = root.dynamicBase(p);
                        if (pairs[b]) continue;
                        pairs[b] = true;
                    }
                    counts[f] = (counts[f] || 0) + 1;
                }
                // named folders alphabetically, loose files last
                const names = Object.keys(counts).sort((a, b) => a === "" ? 1 : b === "" ? -1 : a.localeCompare(b));
                root.files = all;
                root.folders = names.map(n => ({ name: n, count: counts[n] }));
                root.pickFolder();
                root.syncDynamic();
            }
        }
    }

    // keep the selected tab valid; prefer the folder holding the current wallpaper
    function pickFolder() {
        const names = folders.map(f => f.name);
        if (names.length === 0) { folder = ""; return; }
        if (current && files.indexOf(current) >= 0 && names.indexOf(folderOf(current)) >= 0 && !folderPinned) {
            folder = folderOf(current);
            return;
        }
        if (names.indexOf(folder) < 0) folder = names[0];
    }
    property bool folderPinned: false   // set once the user picks a tab by hand
    function selectFolder(f) { folderPinned = true; folder = f; }

    Process {
        id: query
        // awww only knows a clip's poster, so the remembered pick comes along
        command: ["sh", "-c", 'awww query; printf "saved: %s\n" "$(cat "$1" 2>/dev/null)"', "sh", root.stateDir + "/current"]
        stdout: StdioCollector {
            onStreamFinished: {
                const m = text.match(/image: (.+)$/m);
                const saved = text.match(/^saved: (.+)$/m);
                if (m) {
                    root.current = saved && root.video(saved[1]) ? saved[1].trim() : m[1].trim();
                    root.shown = root.current;
                    root.pickFolder();
                    paletteCheck.running = true;
                    root.syncDynamic();
                }
            }
        }
    }

    // the single awww client; `pending` is applied when it exits (or is killed)
    property var pending: null
    Process {
        id: client
        onExited: {
            root.busy = "";
            if (root.pending) {
                const p = root.pending;
                root.pending = null;
                root.run(p.path, p.dur);
            }
        }
    }

    function run(p, dur) {
        if (client.running) {
            pending = { path: p, dur: dur };
            client.running = false;      // kill the one in flight; onExited starts this one
            return;
        }
        shown = p;
        busy = p;
        client.command = ["awww", "img", thumb(p), "--transition-type", "fade", "--transition-duration", String(dur)];
        client.running = true;
    }

    Component.onCompleted: rescan()

    function rescan() {
        scan.running = true;
        query.running = true;
    }

    // hover: static images only; animated ones take too long to be a preview
    function preview(p) {
        restoreTimer.stop();
        if (animated(p) || video(current)) return;
        if (p !== shown) run(p, 0.25);
    }

    // the strip's click: always re-applies (a dead clip player restarts)
    function pick(p) { set(p, 0.3, true); }
    // `force` = a user pick; otherwise the remember / clip / accent side
    // effects only run when the wallpaper actually changes
    function set(p, dur, force) {
        restoreTimer.stop();
        p = variantFor(p);               // a Dynamic member → the one the current mode shows
        const changed = p !== current;
        current = p;
        if (p !== shown) run(p, dur || 0.3);
        if (!changed && !force) return;
        // remember for niri's spawn-at-startup line; args via $1/$2 so paths never hit the shell parser
        // then start / stop the clip player, which reads that file
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && printf "%s\\n" "$2" > "$1/current"; systemctl --user "$3" wallpaper-video.service',
            "sh", stateDir, p, video(p) ? "restart" : "stop"]);
        palette(p);
    }

    // accent colours for Theme's optional follow-wallpaper accent (and niri's
    // focus ring): the wallpaper-accent script from quickshell-bottom.nix
    // writes accent-colors.json atomically, Theme watches it.
    function palette(p) {
        Quickshell.execDetached(["wallpaper-accent", p]);
    }
    // first run after the feature landed: no colours for the current wallpaper yet
    Process {
        id: paletteCheck
        command: ["test", "-s", root.stateDir + "/accent-colors.json"]
        onExited: (code) => { if (code !== 0 && root.current) root.palette(root.current); }
    }

    // called when the pointer leaves a thumbnail; preview() of the next one cancels it
    function restoreSoon() { restoreTimer.restart(); }

    function restore() {
        restoreTimer.stop();
        if (current && shown !== current) run(current, 0.25);
    }

    Timer {
        id: restoreTimer
        interval: 250
        onTriggered: root.restore()
    }
}
