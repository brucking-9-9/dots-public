import QtQuick
import Quickshell
import Quickshell.Wayland
import "services"

// nixos-rebuild strip, one per screen: a thin panel that slides down from the
// top edge once sudo has authenticated (the Switch service sees the first log
// line), shows the latest build line, and slides back up 3 s after a good
// switch. A failed one stays until clicked; the click opens the full log.
// Hovering unfolds it to the last 10 lines. Only the strip itself takes
// input (the window is sized for the unfolded strip).
PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    readonly property int pad: 16   // glow room on the open sides
    readonly property bool active: Switch.state !== "idle"
    readonly property bool failed: Switch.state === "failed"
    property bool shown: false
    property real reveal: 0
    property int elapsed: 0
    readonly property bool more: hover.hovered && shown
    readonly property int lineH: Theme.fontSize + 5

    anchors { top: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    implicitWidth: 620 + 2 * pad
    implicitHeight: 26 + 10 * lineH + 12 + pad
    visible: shown
    WlrLayershell.namespace: "qs-switch"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region { item: body }

    onActiveChanged: {
        if (active) { shown = true; reveal = 1; }
        else reveal = 0;
    }
    Component.onCompleted: if (active) { shown = true; reveal = 1; }
    onRevealChanged: if (reveal === 0 && !active) shown = false
    Behavior on reveal { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

    Timer {   // good switch: hold the result, then slide away
        running: Switch.state === "ok"
        interval: 3000
        onTriggered: Switch.dismiss()
    }
    Timer {
        running: Switch.state === "running"
        interval: 1000
        repeat: true
        triggeredOnStart: true
        onTriggered: win.elapsed = Switch.startedAt > 0 ? Math.round((Date.now() - Switch.startedAt) / 1000) : 0
    }

    readonly property color tone: Switch.state === "ok" ? Theme.green : failed ? Theme.pink : Theme.cyan

    Item {
        id: body
        x: win.pad
        width: parent.width - 2 * win.pad
        height: win.more ? 26 + Math.max(1, Switch.lines.length - 1) * win.lineH + 12 : 26
        Behavior on height { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
        clip: true
        HoverHandler { id: hover }
        // slides down from behind the top edge
        y: -height + win.reveal * height
        opacity: win.reveal

        HudPanel {   // flipped so the cut corners and trim face down, away from the edge
            anchors.fill: parent
            rotation: 180
            cutTL: true; cutTR: true; cutBL: false; cutBR: false
            cut: 8
            soft: false   // the halo layer doesn't follow the hover resize well
            fill: Qt.alpha(Theme.bg, 0.94)
            edge: win.tone
            edgeWidth: 1.2
            glow: 1.6
        }

        Item { id: head; width: parent.width; height: 26 }
        NeonText {
            id: icon
            x: 14
            anchors.verticalCenter: head.verticalCenter
            text: "\u{f1105}"
            color: win.tone
            font.family: Theme.font
            font.pixelSize: Theme.fontSize + 2
            glow: 0.6
            RotationAnimation on rotation {   // spins while building, settles upright after
                running: Switch.state === "running"
                loops: Animation.Infinite
                from: 0; to: 360
                duration: 2400
                onRunningChanged: if (!running) icon.rotation = 0
            }
        }
        Text {
            anchors.left: icon.right
            anchors.leftMargin: 10
            anchors.right: timeLabel.left
            anchors.rightMargin: 10
            anchors.verticalCenter: head.verticalCenter
            text: Switch.state === "ok" ? "switch ok"
                : win.failed ? "switch failed · " + Switch.line
                : Switch.line
            color: Switch.state === "running" ? Theme.dim2 : win.tone
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 1
            font.bold: Switch.state !== "running"
            elide: Text.ElideMiddle
        }
        Text {
            id: timeLabel
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: head.verticalCenter
            text: win.failed ? "click for log" : win.elapsed + "s"
            color: Theme.dim
            font.family: Theme.font
            font.pixelSize: Theme.fontSize - 2
        }

        Column {   // earlier lines, newest first under the header (which shows the newest)
            x: 40
            y: 26
            width: parent.width - 54
            opacity: win.more ? 1 : 0
            Behavior on opacity { NumberAnimation { duration: 180 } }
            Repeater {
                model: Switch.lines.slice(0, -1).reverse()
                Text {
                    required property string modelData
                    width: parent.width
                    height: win.lineH
                    verticalAlignment: Text.AlignVCenter
                    text: modelData
                    color: Theme.dim
                    font.family: Theme.font
                    font.pixelSize: Theme.fontSize - 2
                    elide: Text.ElideMiddle
                }
            }
        }

        TapHandler {
            enabled: win.failed
            onTapped: Switch.openLog()
        }
    }
}
