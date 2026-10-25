import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "services"

// Fan glyph + level/rpm. `mini` (the sys island) is the glyph alone; the full
// form lives in ControlPanel. Wheel = ±5 % (enters manual from the current
// speed), click = max ↔ auto (any other manual level goes to max). The glyph
// turns in 30° steps that ripple hub → tips (a timer, not a smooth animation:
// a few redraws/s at idle); a MAX tag marks max. Greyed out while quiet mode owns the
// fans. Backend: services/Fans.qml → `fan` (power/quiet.nix).
Item {
    id: fc
    property bool mini: false
    property string icon: "\u{efa7}"
    readonly property int glyphW: 18
    readonly property int labelW: Math.ceil(widest.width)
    // unfolded width, for the island's expandedWidth prediction
    readonly property int fullWidth: glyphW + 6 + labelW

    implicitWidth: mini ? glyphW + (Fans.atMax ? 4 + tag.implicitWidth : 0) : fullWidth
    implicitHeight: Theme.panelH
    width: implicitWidth
    Behavior on width { NumberAnimation { duration: Theme.unfoldMs; easing.type: Easing.OutCubic } }

    readonly property bool hot: hh.hovered
    readonly property color tone: Fans.quiet ? Theme.dim : Fans.manual ? Theme.pink : (hot ? Theme.fg : Theme.dim2)

    TextMetrics { id: widest; font: label.font; text: "100% 6.8k" }

    // The turn ripples down the blades, pixel-art style: the glyph is cut into
    // `rings` annuli round its ink centre and each step reaches them one
    // frame apart — hub, middle, tips — before the blades line up again. The
    // wave itself takes a fixed rings × waveMs; the pause between waves
    // follows the real rpm. Placed by fractional x/y, not anchors.centerIn:
    // that rounds to whole pixels and left the glyph ~0.85 px off the pivot.
    Item {
        id: spinner
        width: fc.glyphW; height: fc.glyphW
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter

        readonly property int rings: 3
        // 45° = the biggest kink between rings a 4-blade glyph can show (90° looks unchanged)
        readonly property int stepDeg: 45
        readonly property int waveMs: 220
        // 900 ms between waves at the minimum rpm → 80 ms near max
        readonly property real f: Math.max(0, Math.min(1, (Fans.rpm - 1250) / (6900 - 1250)))
        readonly property int pauseMs: Math.round(900 - 820 * f)
        property var angles: [0, 0, 0]
        property int next: 0      // ring the next frame turns
        Timer {
            running: Fans.ok && Fans.rpm > 0 && !Fans.quiet
            repeat: true
            interval: spinner.next === 0 ? spinner.pauseMs : spinner.waveMs
            onTriggered: {
                const a = spinner.angles.slice();
                a[spinner.next] = (a[spinner.next] + spinner.stepDeg) % 360;
                spinner.angles = a;
                spinner.next = (spinner.next + 1) % spinner.rings;
            }
        }

        readonly property rect ink: inkM.tightBoundingRect
        readonly property real reach: Math.max(ink.width, ink.height) / 2 + 2
        TextMetrics { id: inkM; font.family: Theme.font; font.pixelSize: 16; text: Fans.quiet ? "\u{f081d}" : fc.icon }
        FontMetrics { id: fontM; font: inkM.font }

        Item {   // the rings, glowing as one
            anchors.fill: parent
            layer.enabled: Fans.manual || fc.hot
            layer.effect: MultiEffect {
                autoPaddingEnabled: true
                shadowEnabled: true
                shadowColor: fc.tone
                shadowBlur: 0.8
                shadowHorizontalOffset: 0; shadowVerticalOffset: 0
                shadowOpacity: Fans.manual ? 0.8 : 0.6
            }
            Repeater {
                model: spinner.rings
                Item {
                    id: ring
                    required property int index
                    // cuts at 45 % / 75 % of the reach: the hub alone is round, so turning
                    // just it showed nothing — the first ring takes the blade roots with it
                    readonly property var cuts: [0, 0.45, 0.75, 2]
                    readonly property real r0: spinner.reach * cuts[index]
                    readonly property real r1: spinner.reach * cuts[index + 1]
                    anchors.fill: parent
                    layer.enabled: true
                    layer.effect: MultiEffect { maskEnabled: true; maskSource: annulus }
                    Item {
                        anchors.fill: parent
                        rotation: spinner.angles[ring.index]
                        Text {
                            x: spinner.width / 2 - (spinner.ink.x + spinner.ink.width / 2)
                            y: spinner.height / 2 - (fontM.ascent + spinner.ink.y + spinner.ink.height / 2)
                            text: inkM.text
                            font: inkM.font
                            color: fc.tone
                        }
                    }
                    Item {   // this ring's annulus, the mask
                        id: annulus
                        anchors.fill: parent
                        layer.enabled: true
                        visible: false
                        Shape {
                            anchors.fill: parent
                            ShapePath {
                                fillColor: "white"
                                strokeColor: "transparent"
                                fillRule: ShapePath.OddEvenFill
                                PathAngleArc { centerX: spinner.width / 2; centerY: spinner.height / 2; radiusX: ring.r1; radiusY: ring.r1; startAngle: 0; sweepAngle: 360 }
                                PathMove { x: spinner.width / 2 + ring.r0; y: spinner.height / 2 }
                                PathAngleArc { centerX: spinner.width / 2; centerY: spinner.height / 2; radiusX: ring.r0; radiusY: ring.r0; startAngle: 0; sweepAngle: 360 }
                            }
                        }
                    }
                }
            }
        }
    }
    NeonText {   // max marker, folded island only (the label says it unfolded)
        id: tag
        visible: fc.mini && Fans.atMax
        x: fc.glyphW + 4
        anchors.verticalCenter: parent.verticalCenter
        text: "MAX"
        color: Theme.pink
        font.family: Theme.font
        font.pixelSize: Theme.fontSize - 1
        font.bold: true
        font.letterSpacing: 0.5
        glow: 0.7
    }
    NeonText {
        id: label
        x: fc.glyphW + 6
        width: fc.labelW
        anchors.verticalCenter: parent.verticalCenter
        opacity: fc.mini ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.unfoldMs } }
        horizontalAlignment: Text.AlignLeft
        text: (Fans.quiet ? "quiet" : Fans.atMax ? "MAX" : Fans.manual || Fans.want >= 0 ? Fans.shown + "%" : "auto")
              + " " + (Fans.rpm / 1000).toFixed(1) + "k"
        color: Fans.quiet ? Theme.dim : Fans.manual ? Theme.cyan : (fc.hot ? Theme.fg : Theme.dim2)
        font.family: Theme.font
        font.pixelSize: Theme.fontSize
        glow: Fans.manual ? 0.6 : 0
    }

    HoverHandler { id: hh }
    TapHandler { onTapped: Fans.cycle() }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        // trackpads send many small deltas: step 5 % per whole notch
        property real acc: 0
        onWheel: ev => {
            acc += Audio.wheelNotches(ev);
            const n = Math.trunc(acc);
            if (n !== 0) { acc -= n; Fans.nudge(5 * n); }
        }
    }
}
