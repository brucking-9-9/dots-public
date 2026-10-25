import QtQuick
import "services"

// One waybar module: css padding/margin, a tooltip (`tip`, shown through
// TopUi after GTK's delay), left/right/middle clicks and wheel notches.
// `shown: false` folds it to zero width (the drawers).
Item {
    id: m
    default property alias content: inner.data
    property string tip: ""
    property bool calendar: false      // the clock: tooltip is TopCalendar instead of `tip`
    property bool hand: false          // waybar's `cursor: true`: pointer hand on hover
    property int padX: 7
    property int marginX: 3
    property bool shown: true
    property int foldMs: Theme.drawerMs
    signal clicked(int button)
    signal wheel(real notches)
    readonly property bool hovered: hover.hovered

    implicitWidth: inner.width + 2 * (padX + marginX)
    width: shown ? implicitWidth : 0
    height: Theme.topH
    opacity: shown ? 1 : 0
    visible: shown || opacity > 0.01
    clip: true
    Behavior on width { NumberAnimation { duration: m.foldMs; easing.type: Easing.InOutCubic } }
    Behavior on opacity { NumberAnimation { duration: m.foldMs } }

    Item {
        id: inner
        x: m.marginX + m.padX
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }

    HoverHandler {
        id: hover
        cursorShape: m.hand ? Qt.PointingHandCursor : Qt.ArrowCursor
        onHoveredChanged: hovered ? TopUi.hoverIn(m) : TopUi.hoverOut(m)
    }
    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onTapped: (point, button) => m.clicked(button)
    }
    WheelHandler {
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: ev => {
            const n = Audio.wheelNotches(ev);
            if (n !== 0) m.wheel(n);
        }
    }
}
