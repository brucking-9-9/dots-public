import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray
import "services"

// Just the top bar, for iterating on it next to the live shell without a
// second notification daemon / OSD: `quickshell -p <this dir>/top-only.qml`.
// `qs ipc -p <this file> call top state` dumps what the modules evaluate.
ShellRoot {
    Variants { id: tops; model: Quickshell.screens; TopBar {} }
    TopTip {}
    TopMenu { id: menuPopup }
    IpcHandler {
        target: "top"
        function state(): string {
            const b = tops.instances[0];
            return JSON.stringify({ sysOk: Sys.ok, batPresent: Sys.batPresent, batPct: Sys.batPct, batOk: b.batOk, batText: b.batText,
                sink: Audio.sink ? Audio.sink.name : null, desc: Audio.sink ? Audio.sink.description : null, headphones: b.headphones, volIcon: b.volIcon,
                leftOpen: b.leftOpen, ws: Niri.workspacesFor(b.outputName).map(w => w.idx + (w.is_active ? "*" : "")), output: b.outputName,
                net: Net.iface, wired: Net.wired, bt: b.btText, tray: b.trayCount, tips: b.tipDump() });
        }
        function rows(): string { return JSON.stringify({ handle: TopUi.menuHandle !== null, n: menuPopup.rows.length, rows: menuPopup.rows.map(r => [r.label, r.separator === true, r.enabled, r.sub !== null && r.sub !== undefined]), w: menuPopup.implicitWidth, h: menuPopup.implicitHeight, vis: menuPopup.visible, ready: menuPopup.ready }); }
        // force the popups up without a pointer: `top demo tip|menu|off`
        function demo(what: string): void {
            const b = tops.instances[0];
            if (what === "tip") TopUi.tipItem = b.clockModule;
            else if (what === "menu") TopUi.openMenu(b.netModule, [{ label: "Disconnect", run: () => {} }, { label: "Connect", run: () => {} }, { label: "nmtui", run: () => {} }]);
            else if (what === "sliders") { b.volOpen = true; b.blOpen = true; }
            else if (what === "tray") TopUi.openTrayMenu(b.netModule, SystemTray.items.values[0].menu);
            else if (what === "sub") { const r = TopUi.menuHandle ? null : null; TopUi.pushMenu(SystemTray.items.values[0].menu); }
            else { TopUi.tipItem = null; TopUi.closeMenu(); b.volOpen = false; b.blOpen = false; }
        }
    }
}
