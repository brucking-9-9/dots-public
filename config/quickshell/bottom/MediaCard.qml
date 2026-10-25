import QtQuick
import "services"

// Expanded player, raised above the panel while the island or the card is
// hovered: cover art, title/artist, an oscilloscope seek bar (click to seek)
// and text transport buttons.
Item {
    id: card
    readonly property var player: Media.player
    readonly property bool hovered: hover.hovered
    property bool open: false
    width: 320
    height: 148
    opacity: open ? 1 : 0
    visible: opacity > 0 && player !== null
    Behavior on opacity { NumberAnimation { duration: 180 } }

    HoverHandler { id: hover }

    // keep position moving while visible (Quickshell only pushes it on seeks)
    Timer {
        interval: 250
        repeat: true
        running: card.open && card.player !== null && card.player.isPlaying
        onTriggered: card.player.positionChanged()
    }

    HudPanel {
        anchors.fill: parent
        cutTL: true; cutTR: false; cutBL: false; cutBR: true
        cut: 10
        edge: Theme.cyan
        glow: 10
    }
    Rectangle {   // pink underglow, like the mockup's box-shadow
        anchors.fill: parent
        z: -1
        color: "transparent"
        border.color: Qt.rgba(1, 0, 0.33, 0.25)
        border.width: 1
    }

    Column {
        id: body
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Row {
            width: parent.width
            spacing: 12

            Rectangle {   // art (gradient fallback when no cover)
                width: 64; height: 64
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.pink }
                    GradientStop { position: 0.45; color: "#3a0021" }
                    GradientStop { position: 1; color: Theme.cyan }
                }
                Image {
                    anchors.fill: parent
                    source: card.player ? card.player.trackArtUrl : ""
                    sourceSize: Qt.size(128, 128)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: status === Image.Ready
                }
            }

            Column {
                width: parent.width - 64 - 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3
                Text {
                    width: parent.width
                    text: card.player ? card.player.trackTitle : ""
                    textFormat: Text.PlainText
                    color: Theme.fg
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize + 1
                    font.bold: true
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: card.player
                        ? card.player.trackArtist + (card.player.trackAlbum ? " · " + card.player.trackAlbum : "")
                        : ""
                    textFormat: Text.PlainText
                    color: Theme.purple
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 1
                    elide: Text.ElideRight
                }
            }
        }

        // oscilloscope seek bar
        Canvas {
            id: scope
            width: parent.width
            height: 48
            readonly property real frac: card.player && card.player.length > 0
                ? Math.min(1, card.player.position / card.player.length) : 0
            property var zoneW: [1 / 3, 1 / 3, 1 / 3]   // smoothed section widths

            Connections {
                target: Media
                function onLevelsChanged() { scope.requestPaint(); }
            }
            Connections {
                target: card.player
                function onPositionChanged() { scope.requestPaint(); }
            }
            onFracChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                const w = width, h = height, mid = h / 2;
                ctx.reset();
                ctx.clearRect(0, 0, w, h);
                ctx.strokeStyle = Theme.sel;
                ctx.lineWidth = 1;
                ctx.beginPath(); ctx.moveTo(0, mid); ctx.lineTo(w, mid); ctx.stroke();

                // After Effects "Audio Spectrum" look: one flat line, frequency
                // left to right (cava's 72 bars are log-spaced 50 Hz-10 kHz), a
                // dense zigzag whose height is that frequency's level. Squaring
                // the level keeps quiet bands flat so loud ones read as bursts.
                // Bass | mids | treble sections get wider while they're loud.
                const lv = Media.levels, n = lv.length;
                const level = f => {   // bar value at fractional index f, 0..1
                    const i = Math.floor(f), k = f - i;
                    return (lv[i] * (1 - k) + lv[Math.min(n - 1, i + 1)] * k) / 100;
                };
                const zones = [
                    // cava bars [a, b) (72 bars: 250 Hz ~ bar 22, 4 kHz ~ bar 60),
                    // zigzag wavelength px, line width
                    { a: 0,  b: 22, wl: 6,   lw: 1.8 },   // bass
                    { a: 22, b: 60, wl: 4.5, lw: 1.4 },   // mids
                    { a: 60, b: 72, wl: 3,   lw: 1.1 },   // treble
                ];
                // width follows loudness: weight = 1 + 2 * section energy, eased
                const weights = zones.map(z => {
                    if (!n) return 1;
                    let s = 0;
                    for (let i = z.a; i < Math.min(z.b, n); i++) s += lv[i];
                    return 1 + 2 * s / ((Math.min(z.b, n) - z.a) * 100);
                });
                const total = weights.reduce((a, b) => a + b, 0);
                zoneW = zoneW.map((v, i) => v + (weights[i] / total - v) * 0.25);
                const headX = frac * w;
                let x0 = 0, phase = 0;
                zones.forEach((z, zi) => {
                    const zw = zoneW[zi] * w;
                    const last = Math.min(z.b, n) - 1;
                    z.pts = [];
                    for (let dx = 0; dx <= zw; dx += 1) {
                        const u = dx / zw;
                        const e = n ? level(z.a + u * (last - z.a)) : 0.05;
                        phase += 2 * Math.PI / z.wl;
                        z.pts.push([x0 + dx, mid + Math.sin(phase) * e * e * (mid - 1)]);
                    }
                    x0 += zw;
                });
                // played part: filled under the wave
                ctx.save();
                ctx.beginPath(); ctx.rect(0, 0, headX, h); ctx.clip();
                ctx.fillStyle = Qt.rgba(0, 1, 0.78, 0.25);
                ctx.beginPath(); ctx.moveTo(0, mid);
                for (const z of zones) for (const p of z.pts) ctx.lineTo(p[0], p[1]);
                ctx.lineTo(w, mid); ctx.closePath(); ctx.fill();
                ctx.restore();
                // traces
                ctx.strokeStyle = Theme.cyan;
                let prev = null;   // start each section where the last one ended
                for (const z of zones) {
                    ctx.lineWidth = z.lw;
                    ctx.beginPath();
                    if (prev) ctx.moveTo(prev[0], prev[1]);
                    z.pts.forEach((p, i) => i || prev ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1]));
                    ctx.stroke();
                    prev = z.pts[z.pts.length - 1];
                }
                // head
                ctx.strokeStyle = Theme.pink;
                ctx.lineWidth = 1.5;
                ctx.beginPath(); ctx.moveTo(headX, 0); ctx.lineTo(headX, h); ctx.stroke();
            }

            TapHandler {
                onTapped: (pt, button) => {
                    const p = card.player;
                    if (p && p.canSeek && p.length > 0) p.position = pt.position.x / scope.width * p.length;
                }
            }
        }

        Item {   // time (left) + transport (right)
            width: parent.width
            height: timeTxt.implicitHeight
            Text {
                id: timeTxt
                anchors.left: parent.left
                text: card.player ? Media.fmt(card.player.position) + " / " + Media.fmt(card.player.length) : ""
                color: Theme.yellow
                font.family: Theme.font
                font.pixelSize: Theme.fontSize - 1
                font.letterSpacing: 0.5
            }
            Row {
                id: btns
                anchors.right: parent.right
                spacing: 10
                Repeater {
                    // op strings, not closures: JS functions do not survive the
                    // JS array → QVariant conversion a Repeater model goes through
                    model: ["prev", "toggle", "next", "shuffle"]
                    Text {
                        required property string modelData
                        readonly property bool on: modelData === "shuffle" && card.player ? card.player.shuffle : false
                        // greyed when the player can't do it (shuffle is unsupported on some; next/prev at the ends)
                        readonly property bool can: {
                            const p = card.player;
                            if (!p) return false;
                            switch (modelData) {
                            case "prev":    return p.canGoPrevious;
                            case "next":    return p.canGoNext;
                            case "shuffle": return p.shuffleSupported;
                            default:        return p.canTogglePlaying;
                            }
                        }
                        text: modelData === "prev" ? "[⏮]"
                            : modelData === "next" ? "[⏭]"
                            : modelData === "shuffle" ? "[⇄]"
                            : (card.player && card.player.isPlaying ? "[⏸]" : "[⏵]")
                        color: !can ? Theme.sel : on ? Theme.yellow : (bh.hovered ? Theme.fg : Theme.cyan)
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                        HoverHandler { id: bh }
                        TapHandler {
                            onTapped: {
                                const p = card.player;
                                if (!p || !can) return;
                                if (modelData === "prev") p.previous();
                                else if (modelData === "next") p.next();
                                else if (modelData === "shuffle") p.shuffle = !p.shuffle;
                                else p.togglePlaying();
                            }
                        }
                    }
                }
            }
        }
    }
}
