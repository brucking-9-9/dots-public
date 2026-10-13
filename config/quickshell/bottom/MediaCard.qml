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
            height: 26
            readonly property real frac: card.player && card.player.length > 0
                ? Math.min(1, card.player.position / card.player.length) : 0

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

                const lv = Media.levels;
                const energy = lv.length ? lv.reduce((a, b) => a + b, 0) / (lv.length * 7) : 0.25;
                const amp = 3 + energy * (mid - 3);
                const headX = frac * w;
                const pts = [];
                for (let x = 0; x <= w; x += 2) {
                    const i = lv.length ? Math.floor(x / w * lv.length) : 0;
                    const local = lv.length ? lv[i] / 7 : 0.4;
                    const y = mid + Math.sin(x / 9) * amp * (0.4 + 0.6 * local) * Math.sin(x / 37 + 1)
                                  + Math.sin(x / 3.1) * 1.5 * local;
                    pts.push([x, y]);
                }
                // played part: filled
                ctx.save();
                ctx.beginPath(); ctx.rect(0, 0, headX, h); ctx.clip();
                ctx.beginPath(); ctx.moveTo(0, mid);
                for (const p of pts) ctx.lineTo(p[0], p[1]);
                ctx.lineTo(w, mid); ctx.closePath();
                ctx.fillStyle = Qt.rgba(0, 1, 0.78, 0.25);
                ctx.fill();
                ctx.restore();
                // trace
                ctx.strokeStyle = Theme.cyan;
                ctx.lineWidth = 1.5;
                ctx.beginPath();
                pts.forEach((p, i) => i ? ctx.lineTo(p[0], p[1]) : ctx.moveTo(p[0], p[1]));
                ctx.stroke();
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
                        text: modelData === "prev" ? "[⏮]"
                            : modelData === "next" ? "[⏭]"
                            : modelData === "shuffle" ? "[⇄]"
                            : (card.player && card.player.isPlaying ? "[⏸]" : "[⏵]")
                        color: on ? Theme.yellow : (bh.hovered ? Theme.fg : Theme.cyan)
                        font.family: Theme.font
                        font.pixelSize: Theme.fontSize - 1
                        HoverHandler { id: bh }
                        TapHandler {
                            onTapped: {
                                const p = card.player;
                                if (!p) return;
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
