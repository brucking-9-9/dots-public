import QtQuick
import Quickshell
import Quickshell.Wayland
import "services"

// On-screen display, one per screen: the same angled panel as the Touch ID
// HUD, centred just above the bar, for the volume / mic / brightness /
// keyboard-backlight keys (icon · segmented meter · %) and the media keys
// (transport glyph · artist — title) and caps lock (glyph · CAPS LOCK on/off,
// popped by Osd's LED watcher). Overlay layer so it shows over a
// fullscreen window, empty mask so it never takes a click. Driven by the
// Osd service; `qs ipc -c bottom call osd volume raise` (or `osd pop media`) for testing.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    readonly property int pad: 24   // room for the glow halo all round
    property bool shown: false
    property real reveal: 0

    // the Touch ID HUD anchors to the same spot and matters more (a finger is
    // wanted), so while a prompt is up this one steps over it and drops back after
    property real lift: TouchId.state !== "idle" ? 58 : 0
    Behavior on lift { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    anchors { bottom: true }
    margins.bottom: Theme.panelH + 24 + lift
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    implicitWidth: body.width + 2 * pad
    implicitHeight: body.height + 2 * pad
    visible: shown
    WlrLayershell.namespace: "qs-osd"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    Connections {
        target: Osd
        function onShownChanged() {
            if (Osd.shown) { win.shown = true; win.reveal = 1; }
            else win.reveal = 0;
        }
    }
    onRevealChanged: if (reveal === 0 && !Osd.shown) shown = false
    Behavior on reveal { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    readonly property var player: Media.player
    readonly property bool meter: Osd.kind !== "media" && Osd.kind !== "caps"
    readonly property bool muted: Osd.kind === "volume" ? Audio.muted : Osd.kind === "mic" ? Audio.micMuted : false
    readonly property real level: {
        switch (Osd.kind) {
        case "volume":     return Audio.volume;
        case "mic":        return Audio.micVolume;
        case "brightness": return Osd.screenLevel;
        case "kbd":        return Osd.kbdLevel;
        default:           return 0;
        }
    }
    // same colour language as the island: cyan output, green mic, pink when
    // muted; yellow for the screen, purple for the keyboard; media is cyan;
    // caps lock orange while on, grey when it goes off
    readonly property color tone: {
        if (muted) return Theme.pink;
        switch (Osd.kind) {
        case "caps":       return Osd.caps ? Theme.orange : Theme.dim2;
        case "mic":        return Theme.green;
        case "brightness": return Theme.yellow;
        case "kbd":        return Theme.purple;
        default:           return Theme.cyan;
        }
    }
    readonly property string icon: {
        const g = c => String.fromCodePoint(c);   // nerd-font glyphs by codepoint (literals get mangled in edits)
        switch (Osd.kind) {
        case "volume":     return muted ? g(0xF0581) : level < 0.34 ? g(0xF057F) : level < 0.67 ? g(0xF0580) : g(0xF057E);
        case "mic":        return muted ? g(0xF036D) : g(0xF036C);
        case "brightness": return level < 0.34 ? g(0xF00DE) : level < 0.67 ? g(0xF00DF) : g(0xF00E0);
        case "kbd":        return level === 0 ? g(0xF030E) : g(0xF030C);
        case "caps":       return g(0xF030E);
        case "media":
            switch (Osd.mediaOp) {
            case "next":  return "[⏭]";
            case "prev":  return "[⏮]";
            case "stop":  return "[⏹]";
            case "pause": return "[⏸]";
            default:      return "[⏵]";
            }
        }
        return "";
    }
    readonly property string mediaText: {
        if (Osd.kind === "caps")
            return 'CAPS LOCK <font color="' + (Osd.caps ? Theme.orange : Theme.dim) + '">' + (Osd.caps ? "on" : "off") + '</font>';
        if (!player) return '<font color="' + Theme.dim + '">no player</font>';
        if (Osd.mediaOp === "stop") return '<font color="' + Theme.dim2 + '">stopped</font>';
        const a = player.trackArtist, t = player.trackTitle;
        return (a ? '<font color="' + Theme.purple + '">' + Media.esc(a) + '</font>' : "")
            + (a && t ? " — " : "") + Media.esc(t || "…");
    }

    Item {
        id: body
        anchors.centerIn: parent
        width: row.implicitWidth + 36
        height: row.implicitHeight + 20
        opacity: win.reveal
        scale: 0.92 + 0.08 * win.reveal
        transformOrigin: Item.Bottom

        HudPanel {
            anchors.fill: parent
            cutTL: true; cutTR: true; cutBL: false; cutBR: false
            cut: 10
            soft: true
            fill: Qt.alpha(Theme.bg, 0.96)
            edge: win.tone
            edgeWidth: 1.4
            glow: 2.2
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 12

            NeonText {
                anchors.verticalCenter: parent.verticalCenter
                text: win.icon
                color: win.tone
                font.family: Theme.font
                font.pixelSize: Osd.kind === "media" ? Theme.fontSize + 3 : Theme.fontSize + 8
                glow: win.muted ? 0.6 : 0.4
            }

            // segmented meter, leaning like the wallpaper cards; lit segments
            // carry the tone, the rest the selection grey, muted dims the lot
            Item {
                visible: win.meter
                anchors.verticalCenter: parent.verticalCenter
                width: segs.width + 6
                height: 12
                Row {
                    id: segs
                    anchors.centerIn: parent
                    spacing: 2
                    transform: Matrix4x4 { matrix: Qt.matrix4x4(1, Math.tan(-14 * Math.PI / 180), 0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1) }
                    Repeater {
                        model: 20
                        Rectangle {
                            required property int index
                            readonly property bool lit: index < Math.round(win.level * 20)
                            width: 6; height: 12
                            color: lit ? win.tone : Theme.sel
                            opacity: win.muted ? (lit ? 0.45 : 0.6) : 1
                            Behavior on color { ColorAnimation { duration: 90 } }
                        }
                    }
                }
            }
            Text {
                visible: win.meter
                anchors.verticalCenter: parent.verticalCenter
                text: Audio.pct(win.level)
                color: win.muted ? Theme.dim : Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
                width: 36
                horizontalAlignment: Text.AlignRight
            }

            NeonText {
                visible: !win.meter
                anchors.verticalCenter: parent.verticalCenter
                text: win.mediaText
                textFormat: Text.RichText
                color: Theme.fg
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 1
                font.letterSpacing: 0.5
                glow: 0.25
            }
        }
    }
}
