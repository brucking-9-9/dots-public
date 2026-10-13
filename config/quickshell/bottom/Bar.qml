import QtQuick
import Quickshell
import Quickshell.Wayland
import "services"

// One transparent layer surface per screen, anchored to the bottom, 300 px
// tall, reserving nothing itself (niri's struts.bottom makes the room). Two
// islands always sit in the bottom corners at mini height; hovering one
// unfolds it to full height with more content. The media island lives in the
// centre whenever a player exists: it stays up while something is playing,
// sinks below the edge when paused, hovering the centre of the bottom edge
// slides it back up, and hovering the island raises the full card above it.
// It still reserves its room (and slides aside from an expanded tab) so
// nothing reflows when it appears.
//
//   ▬▬ ▬ kitty hx firefox    ▁▃▅▇ artist — title 󰕾 42% 󰍬 80%    4500K │ 23:02 │ ✉2
//   > _ ▬▬ ▬ 1:kitty● 2:hx 3:firefox●       ⬡ │ ☼⌒☾ 6500K night·auto │ 23:02:17 │ ✉ 2
//
// Only `mask` decides what is clickable: the islands, the media zone, and
// whatever popup is up. Mod+B expands all with the prompt focused and locks
// them until Esc. Mod+D "summons" the launcher alone: the apps island slides
// to the centre, the surface hops to the Overlay layer (the only one niri
// draws above a fullscreen window) with exclusive keyboard focus, and the
// other islands hide until Esc, Mod+D again, or a launch.
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData

    anchors { left: true; right: true; bottom: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    implicitHeight: Theme.windowH
    WlrLayershell.namespace: "qs-bottom"
    // Top normally (hidden under fullscreen windows, like the rest of the desktop);
    // Overlay only while summoned so the launcher shows over a fullscreen game.
    WlrLayershell.layer: summoned ? WlrLayer.Overlay : WlrLayer.Top
    // Never steal typing on hover: only Mod+B / Mod+D / a click on the prompt asks for keys.
    WlrLayershell.keyboardFocus: wantKeyboard || summoned ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    // ── state ────────────────────────────────────────────────────────────
    property bool appsOpen: false        // apps island wants to be expanded
    property bool appsExpanded: false    // …and is (after the media has moved aside)
    property bool appsFolding: false     // folding back; media returns once done
    readonly property bool mediaOpen: media.visible && !summoned && (mediaShown || allLocked || mediaPlaying)   // media island risen
    property bool mediaShown: false      // hovered up from the bottom edge (paused: hover is the only way up)
    readonly property bool resultsOpen: appsExpanded && launcher.results.length > 0   // vertical results popup
    property bool sysOpen: false         // sys island wants to be expanded
    property bool sysExpanded: false
    property bool sysFolding: false
    property bool allLocked: false       // Mod+B
    property bool summoned: false        // Mod+D: launcher alone, centred, on the overlay layer
    property bool wantKeyboard: false
    property bool menuOpen: false
    property bool stripOpen: false
    property bool notifOpen: false
    property bool cardShown: false
    property string menuKind: ""
    property var menuData: null

    readonly property bool anyOpen: appsOpen || mediaOpen || sysOpen
    readonly property int pendingCount: Notif.pending
    readonly property bool fullMask: stripOpen || menuOpen || notifOpen

    readonly property bool appsHover: apps.hovered || menu.hovered || results.hovered
    readonly property bool mediaHover: media.visible && !summoned && (mediaHot.hovered || media.hovered || card.hovered)
    readonly property bool sysHover: sys.hovered || strip.hovered || notifs.hovered

    readonly property bool mediaPlaying: Media.player !== null && Media.player.isPlaying
    readonly property bool appsLock: allLocked || summoned || wantKeyboard || launcher.hasText || menuOpen
    readonly property bool sysLock: allLocked || stripOpen || notifOpen


    // hover in → open; hover out → close after a grace period unless locked
    onAppsHoverChanged: appsHover ? (appsTimer.stop(), appsOpen = true) : (appsLock || appsTimer.restart())
    onSysHoverChanged: sysHover ? (sysTimer.stop(), sysOpen = true) : (sysLock || sysTimer.restart())
    onAppsLockChanged: appsLock ? appsOpen = true : (appsHover || appsTimer.restart())
    onSysLockChanged: sysLock ? sysOpen = true : (sysHover || sysTimer.restart())

    Timer { id: appsTimer; interval: 300; onTriggered: if (!bar.appsLock) bar.closeApps() }
    Timer { id: sysTimer; interval: 300; onTriggered: if (!bar.sysLock) bar.closeSys() }
    // media: the hot zone / island / card hovered → rise; leave → sink after a grace period
    onMediaHoverChanged: mediaHover ? (mediaTimer.stop(), mediaShown = true) : mediaTimer.restart()
    Timer { id: mediaTimer; interval: 350; onTriggered: if (!bar.allLocked) bar.mediaShown = false }

    // media must slide first if the unfolded island would reach it
    readonly property bool appsPushesMedia: !summoned && media.visible && apps.x + apps.expandedWidth + 12 > media.centredX
    readonly property bool sysPushesMedia: media.visible && root.width - Theme.sideMargin - sys.expandedWidth - 12 < media.centredX + media.width
    onAppsOpenChanged: {
        if (appsOpen) { appsFolding = false; if (appsPushesMedia && !appsExpanded) appsDelay.restart(); else appsExpanded = true; }
        else { appsDelay.stop(); if (appsExpanded) { appsFolding = true; appsFoldTimer.restart(); } appsExpanded = false; }
    }
    onSysOpenChanged: {
        if (sysOpen) { sysFolding = false; if (sysPushesMedia && !sysExpanded) sysDelay.restart(); else sysExpanded = true; }
        else { sysDelay.stop(); if (sysExpanded) { sysFolding = true; sysFoldTimer.restart(); } sysExpanded = false; }
    }
    Timer { id: appsDelay; interval: Theme.unfoldMs + 40; onTriggered: if (bar.appsOpen) bar.appsExpanded = true }
    Timer { id: sysDelay; interval: Theme.unfoldMs + 40; onTriggered: if (bar.sysOpen) bar.sysExpanded = true }
    Timer { id: appsFoldTimer; interval: Theme.unfoldMs; onTriggered: bar.appsFolding = false }
    Timer { id: sysFoldTimer; interval: Theme.unfoldMs; onTriggered: bar.sysFolding = false }
    readonly property bool appsAside: appsOpen || appsFolding
    readonly property bool sysAside: sysOpen || sysFolding

    readonly property bool cardHover: bar.mediaOpen && (media.hovered || card.hovered)
    onCardHoverChanged: cardHover ? (cardTimer.stop(), cardShown = true) : cardTimer.restart()
    Timer { id: cardTimer; interval: 150; onTriggered: if (!bar.allLocked) bar.cardShown = false }

    // ── actions ──────────────────────────────────────────────────────────
    function closeApps() {
        appsOpen = false;
        menuOpen = false;
        wantKeyboard = false;
        launcher.clear();
    }
    function closeMedia() {
        cardShown = false;
        mediaShown = false;
    }
    function toggleMedia() {
        if (mediaShown || cardShown) closeMedia();
        else { mediaShown = true; cardShown = true; }
    }
    function closeSys() {
        if (stripOpen) Wallpapers.restore();
        stripOpen = false;
        notifOpen = false;
        sysOpen = false;
    }
    function closeAll() {
        allLocked = false;
        summoned = false;
        closeApps();
        closeSys();
        closeMedia();
    }
    function openAll() {
        summoned = false;
        allLocked = true;
        appsOpen = true; sysOpen = true;
        if (media.visible) { mediaShown = true; cardShown = true; }
        wantKeyboard = true;
        launcher.focusInput();
    }
    function toggle() { allLocked ? closeAll() : openAll(); }
    // Mod+D: only the launcher, centred near the bottom, above everything
    function summon() {
        allLocked = false;
        closeSys();
        closeMedia();
        summoned = true;
        appsOpen = true;
        wantKeyboard = true;
        launcher.focusInput();
    }
    function toggleSummon() { summoned ? closeAll() : summon(); }
    function search(q) {
        if (!allLocked) openAll();
        launcher.setText(q);
    }
    function toggleStrip() {
        if (stripOpen) {
            Wallpapers.restore();
            stripOpen = false;
        } else {
            notifOpen = false;
            sysOpen = true;
            stripOpen = true;
            Wallpapers.rescan();
        }
    }
    function toggleNotifs() {
        if (notifOpen) notifOpen = false;
        else {
            if (stripOpen) { Wallpapers.restore(); stripOpen = false; }
            sysOpen = true;
            notifOpen = true;
        }
    }
    function escapeKey() {
        if (menuOpen) menuOpen = false;
        else if (stripOpen) { Wallpapers.restore(); stripOpen = false; }
        else if (notifOpen) notifOpen = false;
        else closeAll();
    }
    function doMenu(op) {
        // the app behind a pin / transient chip (results have none running)
        const appId = menuKind === "pin" ? (Pins.pins[menuData] ? Pins.pins[menuData].appId : "")
                    : menuKind === "transient" ? menuData : "";
        if (op === "close") Niri.closeApp(appId);
        else if (op === "kill") Niri.killApp(appId);
        else if (menuKind === "pin") {
            if (op === "unpin") Pins.unpin(menuData);
            else if (op === "left") Pins.move(menuData, -1);
            else if (op === "right") Pins.move(menuData, 1);
        } else if (menuKind === "transient" && op === "pin") {
            Pins.pinAppId(menuData);
        } else if (menuKind === "result" && op === "pin") {
            Pins.pinEntry(menuData);
        }
        menuOpen = false;
    }

    mask: Region {
        item: fullMask ? root : null
        regions: [
            Region { item: apps },
            Region { item: bar.summoned ? null : sys }, Region { item: bar.summoned ? null : media },
            Region { item: media.visible && !bar.summoned ? mediaHot : null },
            Region { item: cardHit }, Region { item: bar.menuOpen ? menu : null },
            Region { item: bar.resultsOpen ? results : null },
            Region { item: bar.stripOpen ? strip : null }, Region { item: bar.notifOpen ? notifs : null }
        ]
    }

    Item {
        id: root
        anchors.fill: parent

        // click on empty surface while a popup is up closes it
        TapHandler {
            enabled: bar.fullMask
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: pt => {
                const p = pt.scenePosition;
                const inside = it => it.visible && p.x >= it.x && p.x <= it.x + it.width && p.y >= it.y && p.y <= it.y + it.height;
                if (bar.menuOpen && !inside(menu)) bar.menuOpen = false;
                if (bar.notifOpen && !inside(notifs) && !inside(sys)) bar.notifOpen = false;
                if (bar.stripOpen && !inside(strip) && !inside(sys)) { Wallpapers.restore(); bar.stripOpen = false; }
            }
        }

        // ── apps island (bottom-left, always visible) ────────────────────
        Island {
            id: apps
            expanded: bar.appsExpanded
            expandedWidth: launcher.expandedWidth + 2 * Theme.panelPad
            x: bar.summoned ? Math.round((root.width - width) / 2) : Theme.sideMargin
            Behavior on x { NumberAnimation { duration: Theme.unfoldMs; easing.type: Easing.OutCubic } }
            y: root.height - height
            // leave room for the media island (which slides aside) and the sys island
            width: bar.summoned ? implicitWidth
                 : Math.min(implicitWidth, sys.x - (media.visible ? media.width + 12 : 0) - 12 - Theme.sideMargin)
            clip: true

            Launcher {
                id: launcher
                expanded: bar.appsExpanded
                outputName: bar.screen ? bar.screen.name : ""
                maxWidth: bar.summoned ? Theme.launcherMaxW : (media.visible ? media.x : sys.x) - 30 - Theme.sideMargin - 2 * Theme.panelPad
                anchors.verticalCenter: parent.verticalCenter
                onEscapePressed: bar.escapeKey()
                onLaunched: bar.closeAll()
                onRequestKeyboard: { bar.wantKeyboard = true; launcher.focusInput(); }
                onMenuRequested: (kind, data, chip) => {
                    const p = chip.mapToItem(root, chip.width / 2, 0);
                    bar.menuKind = kind;
                    bar.menuData = data;
                    // running apps also get close (graceful) and kill (SIGKILL)
                    const running = kind === "pin" ? Niri.hasWindow(Pins.pins[data].appId) : kind === "transient";
                    menu.ops = (kind === "pin" ? ["unpin", "left", "right"] : ["pin"]).concat(running ? ["close", "kill"] : []);
                    menu.anchorX = p.x;
                    menu.anchorY = -1;
                    bar.menuOpen = true;
                }
            }
        }

        // ── media island (centre, mini, present while a player exists) ───
        // Up while playing; otherwise tucked just below the edge until the
        // hot zone under it is hovered.
        Item {
            id: mediaHot
            x: media.x; width: media.width
            y: root.height - Theme.miniH; height: Theme.miniH
            HoverHandler { id: hotHover }
            readonly property bool hovered: hotHover.hovered
        }
        Island {
            id: media
            expanded: false
            visible: Media.player !== null
            opacity: bar.mediaOpen ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            readonly property real centredX: Math.round((root.width - width) / 2)
            // keep a 12 px gap from whichever tab is expanded, otherwise stay centred
            x: {
                let x = centredX;
                if (bar.appsAside) x = Math.max(x, apps.x + apps.expandedWidth + 12);
                if (bar.sysAside) x = Math.min(x, root.width - Theme.sideMargin - sys.expandedWidth - 12 - width);
                return Math.round(x);
            }
            y: bar.mediaOpen ? root.height - height : root.height - 3
            Behavior on x { NumberAnimation { duration: Theme.unfoldMs; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            MediaIsland { anchors.verticalCenter: parent.verticalCenter }
        }

        // ── sys island (bottom-right, always visible) ────────────────────
        Island {
            id: sys
            expanded: bar.sysExpanded
            expandedWidth: bar.sysExpanded ? implicitWidth : implicitWidth + Theme.sysUnfoldExtra
            x: root.width - Theme.sideMargin - width
            y: root.height - height
            opacity: bar.summoned ? 0 : 1
            Behavior on opacity { NumberAnimation { duration: 180 } }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Fold {
                    open: bar.sysExpanded
                    anchors.verticalCenter: parent.verticalCenter
                    Row {
                        spacing: 12
                        NeonText {   // wallpaper strip toggle
                            anchors.verticalCenter: parent.verticalCenter
                            text: "⬡"
                            color: bar.stripOpen || wh.hovered ? Theme.fg : Theme.purple
                            font.family: Theme.font
                            font.pixelSize: 16
                            glow: bar.stripOpen || wh.hovered ? 0.9 : 0.4
                            HoverHandler { id: wh }
                            TapHandler { onTapped: bar.toggleStrip() }
                        }
                        Rectangle { width: 1; height: 22; color: Theme.sel; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
                NightArc { mini: !bar.sysExpanded; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 1; height: bar.sysExpanded ? 22 : 14; color: Theme.sel; anchors.verticalCenter: parent.verticalCenter; Behavior on height { NumberAnimation { duration: Theme.unfoldMs } } }
                Clock { mini: !bar.sysExpanded; anchors.verticalCenter: parent.verticalCenter }
                Rectangle { width: 1; height: bar.sysExpanded ? 22 : 14; color: Theme.sel; anchors.verticalCenter: parent.verticalCenter; Behavior on height { NumberAnimation { duration: Theme.unfoldMs } } }
                NeonText {   // pending notifications; right-click = do-not-disturb, middle = mute chime
                    anchors.verticalCenter: parent.verticalCenter
                    text: (Notif.dnd ? "\u{f009b}" : "✉") + (Notif.pending > 0 ? " " + Notif.pending : "") + (Notif.silent ? " \u{f075f}" : "")
                    color: Notif.dnd ? Theme.dim : (Notif.pending > 0 ? Theme.pink : (nh.hovered ? Theme.fg : Theme.dim2))
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    glow: Notif.pending > 0 && !Notif.dnd ? 0.8 : 0
                    HoverHandler { id: nh }
                    TapHandler { acceptedButtons: Qt.LeftButton; onTapped: bar.toggleNotifs() }
                    TapHandler { acceptedButtons: Qt.RightButton; onTapped: Notif.toggleDnd() }
                    TapHandler { acceptedButtons: Qt.MiddleButton; onTapped: Notif.toggleSilent() }
                }
            }
        }

        // ── popups above the islands ─────────────────────────────────────
        ResultList {
            id: results
            open: bar.resultsOpen
            results: launcher.results
            selected: launcher.selected
            x: apps.x + Theme.panelPad
            y: open ? apps.y - height - 6 : apps.y - height + 10
            Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
            onHoverSelected: i => launcher.selected = i
            onActivated: i => launcher.activate(i)
            onPinRequested: (entry, row) => {
                const p = row.mapToItem(root, 0, 0);
                bar.menuKind = "result";
                bar.menuData = entry;
                menu.ops = ["pin"];
                menu.anchorX = p.x + 60;
                menu.anchorY = p.y;
                bar.menuOpen = true;
            }
        }

        ChipMenu {
            id: menu
            visible: bar.menuOpen
            readonly property bool hovered: mh.hovered
            property real anchorY: -1       // >= 0: sit beside this y instead of above the island
            y: anchorY >= 0 ? anchorY - height / 2 + 12 : apps.y - height - 4
            onActivated: op => bar.doMenu(op)
            HoverHandler { id: mh }
        }

        MediaCard {
            id: card
            open: bar.cardShown
            x: Math.round(Math.max(Theme.sideMargin, Math.min(root.width - Theme.sideMargin - width, media.x + media.width / 2 - width / 2)))
            y: open ? media.y - height - 8 : media.y - height + 6
            Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
        Item {   // card + the gap down to the island
            id: cardHit
            x: card.x; y: card.y; width: card.width
            height: bar.cardShown ? media.y - card.y : 0
        }

        WallpaperStrip {
            id: strip
            open: bar.stripOpen
            width: Math.min(root.width - 2 * Theme.sideMargin, Math.max(sys.width, wantedWidth))
            x: Math.max(Theme.sideMargin, sys.x + sys.width - width)
            y: open ? sys.y - height - 10 : sys.y - height + 16
            Behavior on y { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            onChosen: bar.stripOpen = false
        }

        NotifList {
            id: notifs
            open: bar.notifOpen
            x: Math.max(Theme.sideMargin, sys.x + sys.width - width)
            y: open ? sys.y - height - 8 : sys.y - height + 6
            Behavior on y { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
        }
    }
}
