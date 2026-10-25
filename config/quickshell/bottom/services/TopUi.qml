pragma Singleton
import QtQuick
import Quickshell

// Shared tooltip / context-menu state for the top bar: TopModule registers
// hover, the single TopTip and TopMenu popups (shell.qml) anchor to the item.
// A menu is either a static list of { label, run } (network) or a DBus menu
// handle (tray items, rendered by TopMenu through QsMenuOpener; submenus push
// onto `menuStack`).
Singleton {
    id: ui

    property Item tipItem: null        // module whose `tip` the tooltip shows
    property Item pendingItem: null
    property Item menuItem: null
    property var menuEntries: []       // [{ label, run }]
    property var menuHandle: null      // QsMenuHandle (tray)
    property var menuStack: []         // parent handles while inside a submenu

    function hoverIn(item) { pendingItem = item; delay.restart(); }
    function hoverOut(item) {
        if (pendingItem === item) { pendingItem = null; delay.stop(); }
        if (tipItem === item) tipItem = null;
    }
    Timer {
        id: delay
        interval: 500   // GTK's tooltip delay
        onTriggered: if (ui.pendingItem && (ui.pendingItem.tip !== "" || ui.pendingItem.calendar === true)) ui.tipItem = ui.pendingItem
    }

    function openMenu(item, entries) {
        tipItem = null;
        pendingItem = null;
        menuHandle = null;
        menuStack = [];
        menuEntries = entries;
        menuItem = item;
    }
    function openTrayMenu(item, handle) {
        tipItem = null;
        pendingItem = null;
        menuEntries = [];
        menuStack = [];
        menuHandle = handle;
        menuItem = item;
    }
    function pushMenu(handle) { menuStack = menuStack.concat([menuHandle]); menuHandle = handle; }
    function popMenu() {
        if (!menuStack.length) return;
        menuHandle = menuStack[menuStack.length - 1];
        menuStack = menuStack.slice(0, -1);
    }
    function closeMenu() { menuItem = null; menuHandle = null; menuStack = []; }
}
