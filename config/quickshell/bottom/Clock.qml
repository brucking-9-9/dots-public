import QtQuick
import Quickshell

// HH:MM:SS, letter-spaced cyan with a glow, plus a 1 px pink seconds sweep.
Item {
    id: clock
    property bool mini: false
    implicitWidth: txt.implicitWidth
    implicitHeight: Theme.panelH
    width: implicitWidth
    Behavior on width { NumberAnimation { duration: Theme.unfoldMs; easing.type: Easing.OutCubic } }

    SystemClock { id: sys; precision: SystemClock.Seconds }

    NeonText {
        id: txt
        anchors.centerIn: parent
        text: Qt.formatTime(sys.date, clock.mini ? "HH:mm" : "HH:mm:ss")
        color: Theme.cyan
        font.family: Theme.font
        font.pixelSize: 17
        font.letterSpacing: 1.2
        glow: 0.85
    }
    Rectangle {
        anchors.left: txt.left
        anchors.top: txt.bottom
        anchors.topMargin: 3
        height: 1
        color: Theme.pink
        opacity: clock.mini ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: Theme.unfoldMs } }
        width: txt.width * sys.seconds / 59
        Behavior on width {
            enabled: sys.seconds !== 0
            NumberAnimation { duration: 900; easing.type: Easing.Linear }
        }
    }
}
