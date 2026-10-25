import QtQuick
import Quickshell
import "services"

// The one tooltip popup for the top bar (waybar's `tooltip` css): tooltip-bg,
// radius 15, bold fg, 3px 10px padding, under the hovered module.
PopupWindow {
    id: tip
    anchor.item: TopUi.tipItem
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.margins.top: 4
    readonly property bool calendar: TopUi.tipItem !== null && TopUi.tipItem.calendar === true
    visible: TopUi.tipItem !== null && (TopUi.tipItem.tip !== "" || calendar)
    color: "transparent"
    implicitWidth: (calendar ? cal.implicitWidth : label.implicitWidth) + 20
    implicitHeight: (calendar ? cal.implicitHeight : label.implicitHeight) + (calendar ? 16 : 6)

    Rectangle { anchors.fill: parent; radius: Theme.topRadius; color: Theme.moduleBg }
    TopText {
        id: label
        visible: !tip.calendar
        anchors.centerIn: parent
        text: TopUi.tipItem && !tip.calendar ? TopUi.tipItem.tip : ""
        horizontalAlignment: Text.AlignHCenter
    }
    TopCalendar {
        id: cal
        visible: tip.calendar
        anchors.centerIn: parent
        today: sysDay.date
    }
    SystemClock { id: sysDay; precision: SystemClock.Minutes }
}
