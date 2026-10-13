import QtQuick
import QtQuick.Shapes
import "services"

// Sun-on-an-arc temperature control. Drag the sun (6500K left → 2500K right),
// click ☾ for the night preset, click the label to return to the schedule.
Item {
    id: arc
    property bool mini: false
    implicitWidth: shapeFold.width + (mini ? 0 : 8) + labels.implicitWidth
    implicitHeight: Theme.panelH

    readonly property real cx: 30
    readonly property real cy: 30
    readonly property real r: 26
    property real dragK: -1
    readonly property int shownK: dragK > 0 ? dragK : (Night.daemonOk ? Night.temperature : Night.maxK)
    // 0 = full day (left end), 1 = deepest night (right end)
    readonly property real t: Math.min(1, Math.max(0, (Night.maxK - shownK) / (Night.maxK - Night.minK)))
    readonly property real ang: Math.PI * (1 - t)

    Fold {
        id: shapeFold
        open: !arc.mini
        anchors.verticalCenter: parent.verticalCenter
    Item {
        id: shape
        width: 62
        height: 34

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
                strokeColor: Theme.sel
                strokeWidth: 1.5
                fillColor: "transparent"
                PathAngleArc { centerX: arc.cx; centerY: arc.cy; radiusX: arc.r; radiusY: arc.r; startAngle: 180; sweepAngle: 180 }
            }
            ShapePath {   // travelled part, cyan → pink
                strokeColor: Qt.rgba(
                    Theme.cyan.r + (Theme.pink.r - Theme.cyan.r) * arc.t,
                    Theme.cyan.g + (Theme.pink.g - Theme.cyan.g) * arc.t,
                    Theme.cyan.b + (Theme.pink.b - Theme.cyan.b) * arc.t, 1)
                strokeWidth: 1.5
                fillColor: "transparent"
                PathAngleArc { centerX: arc.cx; centerY: arc.cy; radiusX: arc.r; radiusY: arc.r; startAngle: 180; sweepAngle: 180 * arc.t }
            }
        }

        Rectangle {   // sun glow
            x: arc.cx + arc.r * Math.cos(arc.ang) - 8
            y: arc.cy - arc.r * Math.sin(arc.ang) - 8
            width: 16; height: 16; radius: 8
            color: sun.color
            opacity: 0.3
        }
        Rectangle {
            id: sun
            x: arc.cx + arc.r * Math.cos(arc.ang) - 4
            y: arc.cy - arc.r * Math.sin(arc.ang) - 4
            width: 8; height: 8; radius: 4
            color: arc.t < 0.15 ? Theme.yellow : Theme.orange
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            onPressed: mouse => arc.dragTo(mouse.x + 4, mouse.y + 4)
            onPositionChanged: mouse => { if (pressed) arc.dragTo(mouse.x + 4, mouse.y + 4); }
            onReleased: arc.flush()
        }
    }
    }

    Text {   // moon preset, outside the drag area
        visible: !arc.mini
        anchors.left: shapeFold.right
        anchors.leftMargin: -8
        anchors.bottom: shapeFold.bottom
        anchors.bottomMargin: -2
        text: "☾"
        color: Theme.purple
        font.family: Theme.font
        font.pixelSize: 10
        TapHandler { onTapped: Night.setManual(Config.schedule.nightK) }
    }

    Column {
        id: labels
        anchors.left: shapeFold.right
        anchors.leftMargin: arc.mini ? 0 : 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 1
        NeonText {
            text: arc.dragK > 0 ? arc.dragK + "K" : Night.label
            color: Theme.yellow
            font.family: Theme.font
            font.pixelSize: Theme.fontSize
            font.letterSpacing: 0.5
            glow: 0.6
        }
        Text {
            text: Night.currentPhase + " · " + (Night.mode !== "" ? Night.mode : (Night.daemonOk ? "manual" : "no daemon"))
            color: Theme.dim2
            font.family: Theme.font
            font.pixelSize: 9
            visible: !arc.mini
        }
        TapHandler { onTapped: Night.auto() }
    }

    // drag → temperature, throttled to one DBus write per 80 ms
    property int pendingK: -1
    function dragTo(x, y) {
        const dx = x - cx, dy = cy - y;
        let a = Math.atan2(Math.max(dy, 0.0001), dx);   // 0 (right) .. π (left)
        const tt = 1 - a / Math.PI;
        const k = Night.clampK(Night.maxK - tt * (Night.maxK - Night.minK));
        dragK = k;
        pendingK = k;
        if (!throttle.running) {
            Night.setManual(k);
            pendingK = -1;
            throttle.start();
        }
    }
    function flush() {
        if (pendingK > 0) Night.setManual(pendingK);
        pendingK = -1;
        release.restart();
    }
    Timer {
        id: throttle
        interval: 80
        onTriggered: if (arc.pendingK > 0) { Night.setManual(arc.pendingK); arc.pendingK = -1; }
    }
    Timer {   // keep showing the dragged value until the daemon stream catches up
        id: release
        interval: 400
        onTriggered: arc.dragK = -1
    }
}
