import QtQuick

// waybar's pulseaudio/backlight slider: 50 px trough, 5 px high, inactive
// colour, fg highlight, no knob. Slides out of its group on hover.
Item {
    id: s
    property real value: 0      // 0..1
    property real min: 0        // 0..1 floor
    property bool shown: false
    signal moved(real v)

    readonly property int padL: 2
    readonly property int padR: 7
    readonly property int troughW: 50
    implicitWidth: padL + troughW + padR
    width: shown ? implicitWidth : 0
    height: Theme.topH
    opacity: shown ? 1 : 0
    visible: shown || opacity > 0.01
    clip: true
    Behavior on width { NumberAnimation { duration: Theme.sliderMs; easing.type: Easing.InOutCubic } }
    Behavior on opacity { NumberAnimation { duration: Theme.sliderMs } }

    Rectangle {
        id: trough
        x: s.padL
        anchors.verticalCenter: parent.verticalCenter
        width: s.troughW
        height: 5
        radius: 8
        color: Theme.dim
        Rectangle {
            width: Math.max(0, Math.min(1, s.value)) * parent.width
            height: parent.height
            radius: 8
            color: Theme.fg
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor   // waybar: cursor true on both sliders
        function at(x) { s.moved(Math.max(s.min, Math.min(1, (x - s.padL) / s.troughW))); }
        onPressed: mouse => at(mouse.x)
        onPositionChanged: mouse => { if (pressed) at(mouse.x); }
    }
}
