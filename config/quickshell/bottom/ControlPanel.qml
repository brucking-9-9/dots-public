import QtQuick
import "services"

// Night light + fans, popped out above the sys island from its tune glyph
// (the island itself keeps only their condensed forms). Two rows on one
// grid — label | bar | chips — so the columns line up; the bars differ on
// purpose: night is a continuous cyan → pink line with a tick handle
// (6500 K left → 2500 K right), fans are 20 segments of 5 % (dragging from
// auto pins them). The fan row greys out while quiet mode owns the fans.
Item {
    id: panel
    property bool open: false
    width: grid.implicitWidth + 2 * 18
    height: grid.implicitHeight + 2 * 12
    opacity: open ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: 180 } }
    readonly property bool hovered: hover.hovered
    HoverHandler { id: hover }

    readonly property int barW: 180
    readonly property int labelW: 112

    HudPanel {
        anchors.fill: parent
        cutTL: true; cutTR: false; cutBL: false; cutBR: true
        cut: 10
        edge: Theme.purple
        glow: 12
    }

    component Heading: Text {
        color: Theme.dim2
        font.family: Theme.font
        font.pixelSize: 9
        font.letterSpacing: 1.5
    }

    // ── night light state (drag throttled to one DBus write per 80 ms) ─────────────
    property int dragK: -1
    readonly property int shownK: dragK > 0 ? dragK : (Night.daemonOk ? Night.temperature : Night.maxK)
    readonly property real t: Night.depth(shownK)   // 0 day … 1 night
    readonly property color tColor: Qt.rgba(
        Theme.cyan.r + (Theme.pink.r - Theme.cyan.r) * t,
        Theme.cyan.g + (Theme.pink.g - Theme.cyan.g) * t,
        Theme.cyan.b + (Theme.pink.b - Theme.cyan.b) * t, 1)
    property int pendingK: -1
    function dragNight(x) {
        const k = Night.clampK(Night.maxK - Math.max(0, Math.min(1, x / barW)) * (Night.maxK - Night.minK));
        dragK = k; pendingK = k;
        if (!throttle.running) { Night.setManual(k); pendingK = -1; throttle.start(); }
    }
    function flushNight() {
        if (pendingK > 0) Night.setManual(pendingK);
        pendingK = -1;
        release.restart();
    }
    Timer { id: throttle; interval: 80; onTriggered: if (panel.pendingK > 0) { Night.setManual(panel.pendingK); panel.pendingK = -1; } }
    Timer { id: release; interval: 400; onTriggered: panel.dragK = -1 }

    Grid {
        id: grid
        x: 18; y: 12
        columns: 3
        columnSpacing: 14
        rowSpacing: 10
        verticalItemAlignment: Grid.AlignVCenter

        // ── night light ─────────────────────────────────────────────────
        Column {
            width: panel.labelW
            spacing: 2
            Heading { text: "NIGHT · " + Night.currentPhase }
            Row {
                spacing: 6
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Night.phaseGlyph(panel.t)
                    color: panel.t < 0.15 ? Theme.yellow : Theme.orange
                    font.family: Theme.font
                    font.pixelSize: 15
                }
                NeonText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.shownK + "K"
                    color: Theme.yellow
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize
                    font.letterSpacing: 0.5
                    glow: 0.6
                }
            }
        }
        Item {
            width: panel.barW; height: 26
            Rectangle {   // track
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width; height: 2
                color: Theme.sel
            }
            Rectangle {   // travelled part, cyan → current hue
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(2, parent.width * panel.t); height: 2
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0; color: Theme.cyan }
                    GradientStop { position: 1; color: panel.tColor }
                }
            }
            Rectangle {   // glow under the line
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(2, parent.width * panel.t); height: 8; radius: 4
                color: panel.tColor
                opacity: 0.18
            }
            Rectangle {   // tick handle
                x: Math.round(parent.width * panel.t) - 1
                anchors.verticalCenter: parent.verticalCenter
                width: 2; height: nightMa.pressed || nightMa.containsMouse ? 16 : 12
                color: nightMa.containsMouse ? Theme.fg : panel.tColor
                Behavior on height { NumberAnimation { duration: 120 } }
            }
            MouseArea {
                id: nightMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: mouse => panel.dragNight(mouse.x)
                onPositionChanged: mouse => { if (pressed) panel.dragNight(mouse.x); }
                onReleased: panel.flushNight()
            }
        }
        Row {
            spacing: 2
            Chip {
                label: "auto"; mini: true
                selected: Night.mode === "auto"
                onClicked: Night.auto()
            }
            Chip {
                label: "☾"; mini: true
                selected: Night.nightPreset
                onClicked: Night.setManual(Config.schedule.nightK)
            }
        }

        // ── fans ────────────────────────────────────────────────────────
        Column {
            width: panel.labelW
            spacing: 2
            Heading { text: Fans.quiet ? "FANS · quiet" : "FANS · " + Fans.rpm1 + "/" + Fans.rpm2 }
            FanControl { mini: false; height: 18 }
        }
        Item {   // 20 segments, one per 5 %
            width: panel.barW; height: 26
            opacity: Fans.quiet ? 0.4 : 1
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                Repeater {
                    model: 20
                    Rectangle {
                        required property int index
                        readonly property bool on: (index + 1) * 5 <= Fans.shown
                        // dark → light: the low end sinks toward the panel background
                        readonly property real f: 0.25 + 0.75 * index / 19
                        readonly property color base: Fans.manual || Fans.want >= 0 ? Theme.cyan : Theme.dim2
                        width: (panel.barW - 19 * 2) / 20
                        height: 6
                        color: on ? Qt.rgba(Theme.bg.r + (base.r - Theme.bg.r) * f,
                                            Theme.bg.g + (base.g - Theme.bg.g) * f,
                                            Theme.bg.b + (base.b - Theme.bg.b) * f, 1)
                                  : Theme.sel
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                enabled: !Fans.quiet
                cursorShape: Qt.PointingHandCursor
                function at(x) { Fans.set(Math.round(Math.max(0, Math.min(1, x / width)) * 20) * 5); }
                onPressed: mouse => at(mouse.x)
                onPositionChanged: mouse => { if (pressed) at(mouse.x); }
            }
        }
        Row {
            spacing: 2
            Chip {
                label: "auto"; mini: true
                selected: !Fans.manual && !Fans.quiet
                disabled: Fans.quiet
                onClicked: if (Fans.manual) Fans.toggle()
            }
            Chip {
                label: "max"; mini: true
                selected: Fans.manual && Fans.shown === 100
                disabled: Fans.quiet
                onClicked: Fans.set(100)
            }
        }
    }
}
