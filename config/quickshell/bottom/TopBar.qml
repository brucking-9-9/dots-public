import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.SystemTray
import Quickshell.Bluetooth
import "services"

// The top bar: waybar's config.jsonc / modules.jsonc / style.css redrawn in
// QML, same pills, glyphs, paddings and colours (Oct 2026, waybar retired).
// One PanelWindow per screen, 20 px tall with 5 px above and below; the
// exclusive zone is the bar's 20 px plus niri's own 5 px margin = the 25 px
// waybar reserved (GTK layer-shell's auto zone), which struts.top -8 was
// tuned against, so windows don't move.
//
//    power ▸ [bat cpu load] ›    ws        clock        bt vol bl net tray    ‹ [mem temp]
//
//   * left pill    — power-profile glyph (click: next profile, right: quiet
//                    mode; red = performance, green = power-saver, ♪-off
//                    while quiet) + click-to-reveal drawer: battery, cpu, load.
//   * workspaces   — this output's niri workspaces (\u{F0BAF} active,  occupied,
//                     empty); click focuses, wheel moves up/down.
//   * clock        — HH:mm, click toggles the long date form.
//   * right pill   — bluetooth (name of the connected device; click toggles
//                    the radio via toggle_bluetooth, right-click bluetoothctl),
//                    volume and backlight (icon, hover slides out the slider,
//                    wheel steps 2 %, click mutes, right-click pwvucontrol),
//                    network (icon by the default route's device, wifi
//                    tooltip, right-click menu), the system tray (nm-applet…).
//   * right drawer — ‹ reveals memory and core temperature.
//
// Drawer and clock state persist in ~/.local/state/quickshell-bottom/top.json.
// Tooltips/menus are the TopTip / TopMenu popups in shell.qml via TopUi.
PanelWindow {
    id: bar
    required property var modelData
    screen: modelData
    readonly property string outputName: screen ? screen.name : ""

    anchors { top: true; left: true; right: true }
    margins { top: Theme.topMargin; bottom: Theme.topMargin }
    implicitHeight: Theme.topH
    exclusionMode: ExclusionMode.Normal
    exclusiveZone: Theme.topH   // niri adds margins.top itself → 25, as waybar's auto zone was
    color: "transparent"
    WlrLayershell.namespace: "qs-top"
    WlrLayershell.layer: WlrLayer.Top

    // ── persisted state ──────────────────────────────────────────────────
    property bool leftOpen: false
    property bool rightOpen: false
    property bool clockAlt: false
    FileView {
        id: stateFile
        path: Quickshell.env("HOME") + "/.local/state/quickshell-bottom/top.json"
        printErrors: false
        JsonAdapter {
            id: st
            property bool leftOpen: false
            property bool rightOpen: false
            property bool clockAlt: false
        }
        onLoaded: { bar.leftOpen = st.leftOpen; bar.rightOpen = st.rightOpen; bar.clockAlt = st.clockAlt; }
    }
    function save() {
        st.leftOpen = leftOpen; st.rightOpen = rightOpen; st.clockAlt = clockAlt;
        stateFile.writeAdapter();
    }
    function toggleLeft() { leftOpen = !leftOpen; save(); }
    function toggleRight() { rightOpen = !rightOpen; save(); }
    function toggleClock() { clockAlt = !clockAlt; save(); }

    // ── glyphs (modules.jsonc) ───────────────────────────────────────────
    readonly property var wsIcons: ({ active: "\u{F0BAF}", occupied: "\u{F444}", empty: "\u{F4C3}" })
    readonly property var batIcons: ["\u{F007A}", "\u{F007B}", "\u{F007C}", "\u{F007D}", "\u{F007E}", "\u{F007F}", "\u{F0080}", "\u{F0082}", "\u{F0079}"]
    readonly property var tempIcons: ["\u{F2CB}", "\u{F2CA}", "\u{F2C9}", "\u{F2C8}", "\u{F2C7}"]
    readonly property var blIcons: ["\u{F00DE}", "\u{F00DD}", "\u{F00DF}", "\u{F00E0}"]
    readonly property var volIcons: ["\u{F057F}", "\u{F0580}", "\u{F057E}"]
    readonly property var powerIcons: ({ performance: "\u{EF76}", balanced: "\u{F24E}", "power-saver": "\u{F06C}" })

    // waybar's getIcon(): value as a share of 100 picks from the list
    function pick(list, value) { return list[Math.max(0, Math.min(list.length - 1, Math.floor(value * list.length / 100)))]; }
    function hm(seconds) { const h = Math.floor(seconds / 3600), m = Math.floor(seconds % 3600 / 60); return h + ":" + (m < 10 ? "0" : "") + m; }

    // ── battery (sysfs via Sys, as waybar read it) ───────────────────────
    readonly property bool batOk: Sys.ok && Sys.batPresent
    readonly property int batPct: Sys.batPct
    readonly property bool charging: batOk && Sys.batStatus === "Charging"
    readonly property bool full: batOk && (Sys.batStatus === "Full" || batPct >= 100)
    readonly property string batText: !batOk ? ""
        : full ? "\u{F240}"
        : charging ? "\u{F0E7} " + batPct + "% (" + hm(Sys.batSeconds) + ")"
        : pick(batIcons, batPct) + " " + batPct + "%"
    readonly property color batColor: !batOk || charging || full ? Theme.fg : batPct <= 15 ? Theme.topRed : batPct <= 30 ? Theme.topYellow : Theme.fg

    // ── audio ────────────────────────────────────────────────────────────
    readonly property bool headphones: Audio.sink !== null && /headphone|headset/i.test(Audio.sink.name + " " + Audio.sink.description)
    readonly property string volIcon: Audio.muted ? "\u{F075F}" : headphones ? "\u{EE58}" : pick(volIcons, Audio.volume * 100)

    // ── network ──────────────────────────────────────────────────────────
    readonly property int trayCount: trayRow.children.length
    readonly property Item clockModule: clockMod   // top-only.qml's popup demos
    function tipDump() { return { power: powerMod.tip, battery: batMod.tip, cpu: cpuMod.tip, load: loadMod.tip, bt: btMod.tip, vol: volMod.tip, bl: blMod.tip, net: netMod.tip, mem: memMod.tip, temp: tempMod.tip }; }
    readonly property Item netModule: netMod
    property alias volOpen: volGroup.open
    property alias blOpen: blGroup.open
    readonly property string netIcon: Net.wired ? "\u{EF44}" : Net.wifi ? "\u{F1EB}" : "\u{F071}"

    // ── bluetooth ────────────────────────────────────────────────────────
    readonly property var btAdapter: Bluetooth.defaultAdapter
    readonly property bool btOn: btAdapter !== null && btAdapter.enabled
    readonly property var btConnected: btOn ? Bluetooth.devices.values.filter(d => d.connected) : []
    readonly property string btText: !btOn ? "\u{F00B2}" : btConnected.length ? btConnected[0].name : "\u{F00B0}"
    readonly property string btTip: btConnected.map(d => d.batteryAvailable ? d.name + "  \u{F240} " + Math.round(d.battery * 100) + "%" : d.name).join("\n")

    // ── left ─────────────────────────────────────────────────────────────
    Row {
        id: left
        anchors.left: parent.left
        anchors.leftMargin: 3
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8   // #left's margin

        TopPill {   // #left-hidden-top: custom/power + the click-to-reveal drawer
            padX: 12
            TopModule {   // custom/power
                id: powerMod
                padX: 0; marginX: 0
                tip: Power.tooltip
                onClicked: b => b === Qt.RightButton ? Power.toggleQuiet() : Power.next()
                Row {
                    spacing: 0
                    TopText {
                        text: bar.powerIcons[Power.profile]
                        color: Power.profile === "performance" ? Theme.topRed : Power.profile === "power-saver" ? Theme.topGreen : Theme.fg
                    }
                    TopText { visible: Power.quiet; text: " \u{F026}"; color: Theme.topBlue }
                    Item { width: 7; height: 1 }   // margin-right 7px
                }
            }
            TopModule {   // battery
                id: batMod
                shown: bar.leftOpen
                visible: bar.batOk && (shown || opacity > 0.01)
                // waybar's default: "Full in {H} h {M} min" / "Empty in …" (format-time is for the label only)
                tip: !bar.batOk ? "" : bar.full ? "Full" : (bar.charging ? "Full in " : "Empty in ") + Math.floor(Sys.batSeconds / 3600) + " h " + Math.floor(Sys.batSeconds % 3600 / 60) + " min"
                TopText { text: bar.batText; color: bar.batColor }
            }
            TopModule {   // cpu
                id: cpuMod
                shown: bar.leftOpen
                hand: true
                tip: "Total: " + Math.round(Sys.cpu) + "%" + Sys.cores.map((v, i) => "\nCore" + i + ": " + v + "%").join("")
                TopText { text: "\u{F2DB} " + Math.round(Sys.cpu) + "%"; color: Sys.cpu >= 90 ? Theme.topRed : Sys.cpu >= 80 ? Theme.topYellow : Theme.fg }
            }
            TopModule {   // load
                id: loadMod
                shown: bar.leftOpen
                hand: true
                tip: "Load 1: " + Sys.load1.toFixed(2) + "\nLoad 5: " + Sys.load5.toFixed(2) + "\nLoad 15: " + Sys.load15.toFixed(2)
                TopText { text: "\u{F4BC} " + Sys.load1.toFixed(2) + "%" }
            }
            TopModule {   // custom/arrow-right (the drawer toggle)
                padX: 0; marginX: 0
                hand: true
                onClicked: bar.toggleLeft()
                TopText { text: "\u{F460}" }
            }
        }

        TopPill {   // #left: niri/workspaces
            padX: 10
            Repeater {
                model: Niri.workspacesFor(bar.outputName)
                delegate: TopModule {
                    id: ws
                    required property var modelData
                    padX: 2; marginX: 3
                    hand: true
                    onClicked: Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", String(modelData.idx)])
                    onWheel: n => Quickshell.execDetached(["niri", "msg", "action", n > 0 ? "focus-workspace-up" : "focus-workspace-down"])
                    TopText {
                        text: ws.modelData.is_active ? bar.wsIcons.active : Niri.occupied(ws.modelData.id) ? bar.wsIcons.occupied : bar.wsIcons.empty
                        color: ws.modelData.is_urgent ? Theme.topRed : Theme.fg
                    }
                }
            }
        }
    }

    // ── centre: clock ────────────────────────────────────────────────────
    SystemClock { id: sys; precision: SystemClock.Minutes }
    TopPill {
        anchors.centerIn: parent
        padX: 18
        TopModule {
            id: clockMod
            padX: 0; marginX: 0
            calendar: true   // waybar's <tt><small>{calendar}</small></tt> year view
            onClicked: bar.toggleClock()
            TopText { text: Qt.formatDateTime(sys.date, bar.clockAlt ? "HH:mm dd MMMM yyyy" : "HH:mm") }
        }
    }

    // ── right ────────────────────────────────────────────────────────────
    Row {
        id: right
        anchors.right: parent.right
        anchors.rightMargin: 3
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8   // #right's margin

        TopPill {   // #right
            padX: 10
            TopModule {   // bluetooth
                id: btMod
                tip: bar.btTip
                onClicked: b => b === Qt.RightButton ? Niri.spawn(["kitty", "-e", "bluetoothctl"]) : Niri.spawn([Quickshell.env("HOME") + "/.local/bin/toggle_bluetooth"])   // ~/.local/bin is not on niri's PATH
                TopText { text: bar.btText }
            }
            Item {   // group/group-volume: icon + slider on hover (450 ms reveal, 600 ms slide)
                id: volGroup
                width: childrenRect.width
                height: Theme.topH
                property bool open: false
                HoverHandler { onHoveredChanged: hovered ? volDelay.restart() : (volDelay.stop(), volGroup.open = false) }
                Timer { id: volDelay; interval: Theme.sliderDelayMs; onTriggered: volGroup.open = true }
                Row {
                    TopModule {   // pulseaudio
                        id: volMod
                        padX: 8; marginX: 0
                        tip: Audio.pct(Audio.volume)
                        onClicked: b => b === Qt.RightButton ? Niri.spawn(["pwvucontrol"]) : Audio.toggleMute()
                        onWheel: n => Audio.changeVolume(0.02 * n)
                        TopText {
                            text: bar.volIcon
                            font.pixelSize: bar.headphones && !Audio.muted ? Theme.topFontSize : Theme.topIconSize
                            leftPadding: -4   // #pulseaudio padding-left 4px (of the 8)
                        }
                    }
                    TopSlider {   // pulseaudio/slider
                        shown: volGroup.open
                        value: Audio.volume
                        onMoved: v => { if (Audio.sinkOk) Audio.sink.audio.volume = v; }
                    }
                }
            }
            Item {   // group/group-backlight
                id: blGroup
                width: childrenRect.width
                height: Theme.topH
                property bool open: false
                HoverHandler { onHoveredChanged: hovered ? blDelay.restart() : (blDelay.stop(), blGroup.open = false) }
                Timer { id: blDelay; interval: Theme.sliderDelayMs; onTriggered: blGroup.open = true }
                Row {
                    TopModule {   // backlight
                        id: blMod
                        padX: 8; marginX: 0
                        tip: Math.round(Backlight.level * 100) + "%"
                        onWheel: n => Backlight.step(n)
                        TopText { text: bar.pick(bar.blIcons, Backlight.level * 100) }
                    }
                    TopSlider {   // backlight/slider
                        shown: blGroup.open
                        value: Backlight.level
                        min: 0.05
                        onMoved: v => Backlight.set(v * 100)
                    }
                }
            }
            TopModule {   // network
                id: netMod
                padX: 6; marginX: 0
                // the config's one tooltip-format applies to every state (ethernet has no essid/frequency)
                tip: !Net.up ? "" : (Net.wifi ? Net.essid : "") + "\n\nFrequency: " + (Net.wifi ? Net.freqGHz.toFixed(1) : "0.0") + "GHz\nStrength: " + (Net.wifi ? Net.strengthDbm : 0) + "%\n\n"
                    + Net.pow(Net.upBps, "B/s") + " \u{F062} \u{F063} " + Net.pow(Net.downBps, "B/s")
                onClicked: b => { if (b === Qt.RightButton) TopUi.openMenu(netMod, [
                    { label: "Disconnect", run: () => Net.setWifi(false) },
                    { label: "Connect", run: () => Net.setWifi(true) },
                    { label: "nmtui", run: () => Niri.spawn(["kitty", "-e", "nmtui"]) },
                    { label: "\u{EF44} Network settings", run: () => Niri.spawn(["nm-connection-editor"]) }
                ]); }
                TopText { text: bar.netIcon; color: Net.up ? Theme.fg : Theme.topRed }
            }
            Item {   // tray: 13 px icons, 12 px apart, 1px 6px padding
                width: trayRow.width + 12
                height: Theme.topH
                visible: trayRow.children.length > 0
                Row {
                    id: trayRow
                    x: 6
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 12
                    Repeater {
                        model: SystemTray.items
                        delegate: TopModule {
                            id: trayItem
                            required property SystemTrayItem modelData
                            padX: 0; marginX: 0
                            hand: true
                            tip: modelData.tooltipTitle || modelData.title
                            // right-click (or an app whose only UI is the menu): its DBus menu in TopMenu
                            onClicked: b => {
                                if (b === Qt.RightButton || modelData.onlyMenu) { if (modelData.hasMenu) TopUi.openTrayMenu(trayItem, modelData.menu); }
                                else if (b === Qt.MiddleButton) modelData.secondaryActivate();
                                else modelData.activate();
                            }
                            onWheel: n => modelData.scroll(Math.round(n), false)
                            IconImage { source: trayItem.modelData.icon; implicitSize: 13 }
                        }
                    }
                }
            }
        }

        TopPill {   // #right-hidden-top: ‹ drawer with memory + temperature
            padX: 12
            TopModule {   // custom/arrow-left
                padX: 0; marginX: 0
                hand: true
                onClicked: bar.toggleRight()
                TopText { text: "\u{F47D}" }
            }
            TopModule {   // memory
                id: memMod
                shown: bar.rightOpen
                tip: Sys.memUsed.toFixed(1) + "GiB used"
                TopText {
                    text: "\u{EFC5}  " + Sys.memUsed.toFixed(1) + "G/" + Sys.memTotal.toFixed(1) + "G"
                    color: Sys.memPct >= 90 ? Theme.topRed : Sys.memPct >= 80 ? Theme.topYellow : Theme.fg
                }
            }
            TopModule {   // temperature
                id: tempMod
                shown: bar.rightOpen
                tip: Math.round(Sys.temp) + "°C"
                TopText { text: bar.pick(bar.tempIcons, Sys.temp) + " " + Math.round(Sys.temp) + "°"; color: Sys.temp >= 90 ? Theme.topRed : Theme.fg }
            }
        }
    }
}
