import QtQuick
import Quickshell
import Quickshell.Wayland
import "services"

// Fingerprint prompt HUD, one per screen: a small angled panel centred just
// above the bar whenever something (sudo, swaylock, polkit, the greeter) is
// waiting on the sensor. Overlay layer so it shows over fullscreen windows,
// empty input mask so it never steals a click or hover from the prompt
// underneath. Driven by the TouchId service; `qs ipc -c bottom call touchid
// set waiting|scanning|matched|retry|failed|idle` fakes it for testing.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    readonly property int pad: 24   // room for the glow halo all round
    readonly property bool active: TouchId.state !== "idle"
    // the label keeps its last real state through the fade-out
    property string shownState: "waiting"
    property bool shown: false
    property real reveal: 0
    property real pulse: 0

    anchors { bottom: true }
    margins.bottom: Theme.panelH + 24
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    implicitWidth: body.width + 2 * pad
    implicitHeight: body.height + 2 * pad
    visible: shown
    WlrLayershell.namespace: "qs-touchid"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {}

    onActiveChanged: {
        if (active) { shown = true; reveal = 1; }
        else reveal = 0;
    }
    onRevealChanged: if (reveal === 0 && !active) shown = false
    Connections {
        target: TouchId
        function onStateChanged() { if (TouchId.state !== "idle") win.shownState = TouchId.state; }
    }
    Behavior on reveal { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    readonly property color tone: {
        switch (shownState) {
        case "matched": return Theme.green;
        case "retry":   return Theme.yellow;
        case "failed":  return Theme.pink;
        default:        return Theme.cyan;
        }
    }
    readonly property string label: {
        switch (shownState) {
        case "scanning": return "Reading…";
        case "matched":  return "Recognised";
        case "retry":    return "Try again";
        case "failed":   return "Touch ID unavailable";
        default:         return "Touch the sensor";
        }
    }

    // slow breathing while the sensor waits for a finger
    SequentialAnimation on pulse {
        running: win.shownState === "waiting" && win.shown
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 700; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 700; easing.type: Easing.InOutSine }
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
            glow: win.shownState === "waiting" ? 1.2 + win.pulse * 2.4 : 2.2
        }

        Row {
            id: row
            anchors.centerIn: parent
            spacing: 10
            NeonText {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{f0237}"   // nf-md-fingerprint (escape: literals get mangled in edits)
                color: win.tone
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 8
                glow: 0.5 + win.pulse * 0.4
            }
            NeonText {
                anchors.verticalCenter: parent.verticalCenter
                text: win.label
                color: win.tone
                font.family: Theme.font
                font.pixelSize: Theme.fontSize + 1
                font.bold: true
                font.letterSpacing: 1
                glow: 0.35
            }
        }
    }
}
